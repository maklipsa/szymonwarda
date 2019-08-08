---
layout: post
title: How to model hierarchical data in noSQL databases
description: "Modeling hierarchical data in noSQL databases (or in SQL databases without support for CTE) isn't easy or ideal. But there are a few options."
modified: 2019-07-15
tags: [data modeling, CTE, SQL, SQL Server, Mongo, DynamoDB, hierarchy]
series: "Data modeling"
image:
  feature: data/2019-07-15-How-to-model-hierarchical-data-in-noSQL-datababases/logo.jpg
---

Querying hierarchical data is always where the big boys of SQL shined. And I really mean the **big boys** part since <s>only Oracle, and Microsoft SQL Server have support for CTE</s> [As Thomas Levesque pointed out in the comments, not only those have support for CTE. Full list on [wikipedia](https://en.wikipedia.org/wiki/Hierarchical_and_recursive_queries_in_SQL#Common_table_expression)] (**C**ommon **T**able **E**xpressions) that allow for executing one SQL statement what will fetch a subtree.
There are data modeling approaches that allow for doing hierarchical data reads with noSQL databases and databases without support for CTE.

<!--MORE-->

# An Example

The most common and obvious example of hierarchical data is the family tree (we are using parent and child when talking about hierarchical data for a reason). But because of limitations that we will discuss in the end, let's look at another widespread usage: folder structure.

![](https://upload.wikimedia.org/wikipedia/commons/6/69/FolderStructure_07ShotsDepartmentsDetailed.jpg)

Modeling the structure in a relational database is very easy and can be done in one table:

| Id | Name     | ParentId |
|:---|:---------|:---------|
| 1  | 07-Shots | null |
| 2  | EX-000 | 2 |
| 3  | 0000 | 2 |
| 4  | Anin | 3 |
| 5  | Cloth | 3 |

names are self-explanatory.

<style>
    table {
    border-collapse: collapse;
    width: auto !important;
    }
    table, th, td {
    border: 1px solid black;
    }
</style>

# SQL

As I wrote earlier, with SQL, we can use CTE. It will look more or less like this:

```sql
WITH Folder_CTE (Id, Name)
AS
(
    -- Select the root
    SELECT 
        rootParent.Id,
        rootParent.Name
    FROM Folder as rootParent
    Where Id= -- The most parent Id from which we want to read the structure

    -- Union the result
    UNION ALL

    -- Select the next level of hierarchy by joining Folder with the already selected elements 
    SELECT 
        Id,
        Name
    FROM  Folder as child
    Join Folder_CTE as parent on child.ParentId = parent.Id -- Join existing with new. 
)
-- Select the whole result
SELECT     
    Id,
    Name,
    Surname
FROM Folder_CTE

```

What will happen is SQL Server engine will unwind the query fetching results until no new results are returned. It still means doing multiple joins, but the performance penalty isn't that big.

There are some limits to this approach.
- As with most  (all to my knowledge) programming languages, there is a limit to this recursion. In case of SQL Server it is [100 by default](https://stackoverflow.com/questions/2644281/how-many-maximum-recursion-possible-for-cte-in-sql-server) but [can be changed to 32,767](https://social.msdn.microsoft.com/Forums/sqlserver/en-US/db9187df-5c0e-4fe6-bcb7-5d8039fab279/capacity-of-cte?forum=sqldatabaseengine). With OLTP (**O**n**l**ine **T**ransaction **P**rocessing) loads this shouldn't be a problem. For reporting (OLAP - **O**n**l**ine **A**nalytics **P**rocessing), you should be denormalizing your data anyway.

{% include /newsletter.html %}

# Modeling hierarchy in noSQL database or without CTE 

Techniques for modeling hierarchy efficiently can be applied in noSQL databases and in SQL databases without the support for CTE.

## Application recursion

The first approach is to fetch each individual layer of hierarchy one at a time with the looping done by the application. 
The initial SQLs will look like this:

```sql
SELECT 
    Id,
    Name
FROM Folder
```

The next SQL will look like this:

```sql
SELECT 
    Id,
    Name
FROM  Folder
Where ParentId IN (...) --Ids of parents read in the previous iteration
```

There are a few problems with this approach:

- We will be executing multiple SQL queries
- The `IN` operator has a limit to the number of elements it can have. I remember it being around 2100, but now the documentation mentions [many thousands](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/in-transact-sql?view=sql-server-2017).
- The query plan optimizer selects existing plans for procedures with **the same text and number of parameters** (if you are sending parameter **values** in the query text please stop reading and fix it). For every laver of hierarchy, we will be changing the number of `IN` parameters (`@p1, @p2, @p3, .... @pN`) so every query will have the overhead of the optimizer.

## Building the hierarchy in the application

Another approach is to get all the data, build the hierarchy in the app, and then do filtering. If we will be holding the data in the application cache, this is the simplest solution, so let's not over enginer.

## Hierarchy path

The idea of this approach is to extend our object/table with one additional field - `HierarchyPath`:

```json
{
    "Id":
    "Name":
    "ParentId":
    "HierarchyPath":
}
```

In this field, we put Ids of our parents (from the furthest away to the closest) separated by some unique character. Like this:

```
5$18$201$8
```

For folder structure example from the start of the post, it will look like this:

| Id | Name     | ParentId |HierarchyPath |
|:---|:---------|:---------|:-------------|
| 1  | 07-Shots | null ||
| 2  | EX-000 | 2 |1$|
| 3  | 0000 | 2 |1$2$|
| 4  | Anin | 3 |1$2$3$|
| 5  | Cloth | 3 |1$2$3$|


Where `$` plays the role of the separator.

You might say. It's stupid. Why would this make it any better?
We are missing two additional ingredients:

- Create a **text index** on the field.
- Use `StartsWith` (or a right hand like) to search for the structure.

We can't use a standard index since it will create an index of hashed values. That will not help us since a `StartsWith` on hashes just doesn't make any sense. **We need to query actual values**.
This type of indexes are available in most document databases under different names:

- [special text indexes in MongoDB](https://dzone.com/articles/indexing-in-mongodb)
- [range indexes in CosmosDB](https://docs.microsoft.com/en-us/azure/cosmos-db/index-policy)
- [sort keys in DynamoDB](https://aws.amazon.com/blogs/database/using-sort-keys-to-organize-data-in-amazon-dynamodb/)

In our case, the query will look more or less like this :

```sql
SELECT 
    Id,
    Name
FROM Folder
Where HierarchyPath StartsWith "1$"
```

Using this approach, we can use a single query to select the whole subtree without doing a scan over all the records.

### Criticism

When I saw it, it felt like this:

![plane ducktaping](/data/2019-07-15-How-to-model-hierarchical-data-in-noSQL-datababases/engine.jpg)
source: Daily Mail.

But the same as with the image, going deeper made me appreciate the solution more. For the plane ducktape I will give it to the experts:

<iframe width="560" height="315" src="https://www.youtube.com/embed/mG6gHpP6r1o" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

### Limitations:

We have the "feeling" part sorted, so let's talk about the limitations.:

#### Selecting the identifier

This one isn't significant, but being aware of.
When using string identifiers inputted by users selecting the `HierarchyPath` separator isn't that simple since it can't exist in the `Id` itself.  

#### Multiple parent scenario.

This limitation is why we didn't model the parent-child / family tree scenario. In most cases, you have at least two (biological) parents, and the only way to support this is to generate all paths (all 2^N of them where `N` is the depth of the structure)

#### Changing the `Id` or the `ParentId`

When we change the `Id`, or the hierarchy structure, we need to update the `HierarchyPath` in the whole subtree. Solution for this varies a but for SQL and noSQL databases.

With SQL databases we can use a trigger (I know triggers are bad, but this isn't business logic but technical, so they are less bad here).
The main benefit of doing it this way is that triggers are executed in the same transaction, so we will not lose data integrity.

Even noSQL databases that offer the functionality of a trigger don't execute them in the same transaction. Here we are left with eventual consistency.

The approach that can be used in both SQL and noSQL implementations is to trigger a background job (AWS Lambda, Azure Function, or a [Hangfire job](/Don't %20do%20it%20now!%20Part%202.%20Background%20tasks,%20job%20queuing%20and%20scheduling%20with%20Hangfire/) that will go over the data and update the `HierarchyPath` values.

### Starting from the middle

The last, and a quite significant problem is that we can't effectively ask for substructure that would start in the middle of the tree. When starting from the middle, we can't use a `StartsWith` clause, but will have to go with `Contains`. This will scan all values in the index. It will still be faster than scanning the documents, but not as optimal as `StartsWith`. 

# Summary

The solutions above aren't ideal, but no answer is. As always think about the pros and cons and select the best for your use case.