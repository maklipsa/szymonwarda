---
layout: post
title: Modeling version and temporary state in noSQL databases
description: "Versioning is a must in most systems. 
When looking deeper, this problem is very similar to storing draft state. Here we explore a few ways to model this in SQL and noSQL databases."
modified: 2019-07-22
tags: [data modeling, SQL, SQL Server, Mongo, DynamoDB, draft, versioning, auditing, ACID transactions]
series: "Data modeling"
image:
  feature: data/2019-07-22-Modeling-version-and-temporary-state-in-noSQL-databases/logo.jpg
---

The problem of storing draft state and auditing is not limited to noSQL databases, and as [previously](/How-to-model-hierarchical-data-in-noSQL-datababases/), below patterns can be applied to SQL modeling. But because noSQL databases are, in most cases, lacking transactionality over multiple partitions, the problem is harder there. Making it more interesting :)
Additionally, smart use of neet features of noSQL databases allows for a novel solution. 

# The problem(s):

## Problem 1: Storing temporary state

Most developers cringe when they hear about storing temporary state, but can't imagine living without `Save as draft` in Gmail, or git stash :)
Give the users what You expect. 
A  different few use-cases :

- The user can edit a document and save it as a draft. That draft can be later on committed or discarded.
- UI flow requires a page reload when working on a single object. I know that we have SPA applications now, but not everywhere and we might be switching between different systems, or refactoring a legacy system.
- Our document validation logic is quite complex, requires external HTTP calls, takes a long time to execute, and sometimes requires retries. Since we are good developers, we don’t run that logic during saving but save as draft, schedule a background task to do the validation. If something fails, we notify the user - a good UX.

<!--MORE-->

All the above can be simplified to a problem of storing not confirmed data.
We can solve it in a few ways:

#### Slap a  `State` flag field with two states: `Draft` and `Confirmed` to the object. 

This is one of the most common solutions I see in systems. It is effortless, and those are all of its advantages.
The list of disadvantages is longer:

- Everyone has to remember to add `State = Confirmed` to every query over this collection/table.
- Modeling different objects (`DraftOrder` and `Order`) using enums is breaking SOLID principles.
- Adding a `Status` property opens the gates to other states. If we leave opened gates, we can be sure that dragons🐉 will come.
- We can't reuse the required fields, and validation logic since a draft is not a full object. Leading us to objects that are the same but are not the same.

#### Add a boolean field `IsDraft`. 

It might look like a good workaround to not leaving the gates open. But it is even worse because more flag fields will come making the problem of state distributed (current state = SUM(all flag fields)).

#### A separate table/collection to store the draft object. 

We can create a separate table or collection to store draft state. Sounds OK, but again we have some drawbacks here:

- When migrating object structure, we have to migrate the structure of the original object **and** the drafts.
- Most noSQL databases guarantee transactionality only in the scope of a single partition. We loose this by splitting the collections.

## Problem 2: Entity auditing

In essence: Who changed what and when. A must-have in most financial systems and with time will be implemented in every system that allows for any user data update. Why?


<div style="text-align:center"><img src="/data/2019-07-22-Modeling-version-and-temporary-state-in-noSQL-databases/House.jpg" /></div>

Why did I say that those two problems are very similar? Change the `State` to `VersionNumber` add who and when did the change and we have versioning. I know I am oversimplifying but stay with me.

Now for a few well-known patterns:

### Storing only the changed fields

Because we want to track changes, we can only store the fields that changed. We will end up with something like this:


| FieldName | NewValue |  Date      | ChangingUser  | ChangeGroup |
|:----------|:---------|:-----------|:--------------|:------------|
| Name      | Anna     | 2019-07-19 | Rick Sanchez  | 10          |
| Surname   | Smith    | 2019-07-19 | Beth Smith    | 10          |

Where:

- `FieldName` - name of the field what was changed
- `NewValue` - as the name suggests, the new value of the field
- `Date` and `ChangingUser` - date and the user responsible for the change
- `ChangeGroup` - a unique number combining all changes in one save/update action

<style>
    table {
    border-collapse: collapse;
    width: auto !important;
    }
    table, th, td {
    border: 1px solid black;
    }
    th{
      font-weight: bold;
    }
</style>

The main benefits of this approach:

- We can very quickly answer the question who changed a particular field
- Since in most cases, we change a small percentage of all properties, this solution saves a lot of space.

While it is very flexible, the flexibility has some drawbacks:

- When migrating the object structure, we also have to update `FieldName` values.
- Reading object state in a specific moment in time is quite complicated. Requires reading all past events from the given date and applying them in order.
- Auditing adding and removing from lists is not that easy.

### Storing full objects with audit data

In this approach, we store the whole changed object (as a blob or in a structured way) and only append audit data to it. 
The database structure would look something like this:

| Id | Original Entity Properties | EntityId | Date      | ChangingUser  |
|:---|:---------------------------|:---------|:----------|:--------------|
| 0  | {...}                      |    10    |2018-06-19 | Rick Sanchez     |
| 1  | {...}                      |    10    |2019-07-19 | Evil Morty    |

Again, there are plusses:

- getting the state in time is very easy
- very easy to implement
- object complexity is not an issue.

And minuses:

- we are storing a lot of duplicated data.
- getting the information who changed a particular field is a non-trivial task.

{% include /newsletter.html %}

# Alternative solution

All the above solutions can be implemented in SQL and noSQL databases, but they were designed with the first in mind.
When we take into account features that noSQL databases offer:

- `PartitionKey`/`PrimaryKey` can be assigned to multiple rows/objects/states.
- `Id`/`SecondaryKey`  can be used as a drill-down key to a specific object.
- The ability to do commands pre-checks. A pre-check is an `if` statement. It has two properties:
    - is executed in the same transaction before the operation.
    - if it returns false, the operation won't execute.

Having the above allows us for a bit different solution:

| PartitionKey | Version | CurrentVersion | Entity business attributes |
|:-------------|:--------|:---------------|:---------------------------|
| 0            | 0       |     2          | {...}                      |
| 0            | 1       |                | {...}                      |
| 0            | 2       |                | {...}                      |

Legend:

- `PartitionKey` - primary entity key. It doesn't change and is the **boundary of our transaction**.
- `Version` - as the name suggests, the number of the object version. **It is our secondary key.**
- `CurrentVersion` - this field might look like an unnecessary duplication but isn't. We use it for optimistic locking. See the processes implementation below.

Additional rules:

- Row with `Version=0` is always the current row.
- There is a unique index on `(PartitionKey, Version)`.
- `CurrentVersion` is the last version that was approved.

Now to the processes. We have two:

### Start editing

1. Calculate the highest version

```sql
Select MAX(Version) Where PartitionKey=X
```

2. Copy the Version 0 item to a new record with Version = newMax +1 

```sql
COPY (PartitionKey, Version, CurrentVersion, ....) Values (v0.PartitionKey, newMaxVersion, v0.CurrentVersion, v0 business properties....) 
```

This is why we have a unique index on `(PartitionKey, Version)` pair. The `newMaxVersion` calculation is done in a separate call/transaction, so there is no guarantee that nothing happened in the middle (no new version was created). If a new version was created in the meantime, we will get an error. All we have to do is to recalculate the `newMaxVersion` and try to do a new insert. 

### Approve version

Here, we use only one statement:

```sql
UPDATE v0.CurrentVersion = newRow.Version, v0.BusiessProp = newRow.BusinessProp IF v0.CurrentVersion = newRow.CurrentVersion
```

Some explanation to the above:

- `v0` - the `Version = 0` row.
- `newRow` - our new row.

#### Why does it work?

`IF v0.CurrentVersion = newRow.CurrentVersion` is a command pre-check mentioned before. If this statement is false, the operation will fail. 
What it gives us, and why do we have it? 
We are comparing the `CurrentVersion` of the current state of the record with the `CurrentVersion` of our row when we started editing.

When will this fail? Think about it.

Remember that we are updating the `CurrentVersion` **with each approval**. It will fail if someone approved a version between **us** starting editing and approving the version. 
Without the `if` we would override changes made by someone else. With it, we will discover a version conflict that has to be resolved.

Another benefit to this approach is ACID like transactionality from starting editing to approving the version.

# Conclusion

Yes, noSQL databases are simpler and less powerful in terms of features than their SQL cousins. But data modeling is about looking at the limitations and turning them into advantages.