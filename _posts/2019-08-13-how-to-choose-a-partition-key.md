---
layout: post
title: How to choose the partition key
description: ""
modified: 2019-08-13
tags: [nosql, databases, Cosmos DB, DynamoDB, architecture]
image:
  feature: data/2019-08-13-how-to-choose-a-partition-key/logo.jpg
---

NoSQL PaaS databases like AWS DynamoDB or Cosmos DB offer incredible capabilities in scale, speed, and availability. There is also a dark side to those databases. They will punish anyone greatly for mistakes. And no mistakes are punished more than choosing the wrong partition key. Below is an ORDERED list on how to approach selecting the partition key.

<!--MORE-->

## 1. Transaction boundary

I can’t stress this enough. 

<div class="center">
    <div class="button" >This is the most critical factor. If our transaction boundary is wrong, please don’t even think about using this partition key.
    </div>
</div>

Now to elaborate.

In Cosmos DB and DynamoDB partition is the transaction boundary. An operation performed over records with `N` partition keys (and so in `N` partitions) is split into `N` separate transactions. 
Each partition transaction can fail or succeed independently with no rollback of the primary transaction.

**If some operations fail, the changes to other partitions won’t be rollbacked.**

There is no way around this limitation.

Why is this requirement so essential? We have to take into account a few limitations:

- Both databases have minimal capabilities for multi-operation transactions (Cosmos DB supports them only in [stored procedures, pre/post triggers, user-defined-functions (UDFs)](https://docs.microsoft.com/pl-pl/azure/cosmos-db/database-transactions-optimistic-concurrency#multi-item-transactions)). 
- We don't have transaction isolation levels like in relational databases. 
- There is no option to lock a record for editing.

The above limitations mean that we will encounter a lot more cases when data changed between our operations.
To not override data Cosmos DB and DynamoDB uses optimistic locking. It guarantees that the application will know that some changes weren't applied, but won't prevent data inconsistency.

Therefore not platform failure, but changes executed between operations will be the main reason why we might want to revert changes.

> I wrote how to simulate transaction isolation on noSQL databases in the [previous post](/modeling-version-and-temporary-state-in-nosql-databases/).

## 2. Size limitation

The obvious solution to the lack of transactionality over multiple partition keys is to store everything in one partition. 
Not so fast. Cosmos DB and DynamoDB have a **hard limit on partition size - 10 GB**. ([DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LSI.html#LSI.ItemCollections.SizeLimit), [CosmosDB](https://docs.microsoft.com/en-us/azure/cosmos-db/partitioning-overview)).
Making matters worse, this is not a limit only on data, but all the things around it like indexes. 
When the limit is reached, all operations increasing the partition size will fail.
As with the transaction boundary, this is a hard limit, and can't be changed.

## 3. Partition key values can't be updated

When creating a table/collection, we have to define a path to the property which value will be used as the partition id.
Selecting a property as the partition adds some additional requirements on it. There are some type and size limitations, but most importantly, this property has to be present in every document in the collection/table.

From the application logic, it is just like any other required property. With one exception:

<div class="center">
    <div class="button" ><b>Values of properties designated as partition keys can't be changed.</b></div>
</div>

Why?

### Why partition keys values can't be changed?

Let's think about it. We know that:

- The partition is the boundary of the transaction.
- All documents with the same partition key value are in one partition.
- The partition contains documents with the same partition key value.

The change of a partition key property value would spawn across two partitions (old, and new). However, that won't be transactional. 
For this reason, Cosmos DB throws an exception if we try to change the value of the partition key property.

## 4. Performance limitation

One partition can't be split across multiple servers ([DynamoDB can split a single partition using a range key](https://stackoverflow.com/questions/40272600/is-there-a-dynamodb-max-partition-size-of-10gb-for-a-single-partition-key-value), but this is more or less equal to having a more detailed partition key value). This leads to an obvious limitation: 

<div class="center">
    <div class="button" ><b>Partitions have a limit on the number of operations a second they can perform.</b></div>
</div>

Since partitions have limited performance capabilities we might want to distribute queries over multiple partitions. In general, this is a good practice but has to be executed with one thing in mind.

> NoSQL databases have a named anti-pattern for partitions that are used more than others - **hot partitions**.

We have to be careful with load distribution because of:

## 5. Cost

One of the first steps in query execution in Cosmos DB and DynamoDB is to send the query to proper partitions.
When we don't provide a value for the partition key property in the query, the engine executes it on **all partitions**. 
Even if the query executed on the partition doesn't return any results, we will still pay for the used compute resources. Most of those queries should end on index scans. This little expense is multiplied by the number of partitions and might end up a significant one in the end.

A good practice is to design queries so that they always execute on as few partitions as possible.

# Conclusion

If anyone expected a straightforward answer on how to choose the partition key, sorry for letting you down. There is no simple answer. As always, it depends.
Choosing the partition key is always a trade-off:

- Large transaction boundary <b>or</b> the peace of mind of small partitions?
- Risk of hot partitions <b>or</b> more expensive queries?
