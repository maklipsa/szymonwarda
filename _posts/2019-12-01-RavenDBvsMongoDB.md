---
layout: post
title: MongoDB vs RavenDB 
description: "A comparison between MongoDB and RavenDB"
modified: 2019-11-01
tags: [MongoDB, RavenDB, databases, comparison, transactions, in-deepth, review]
image:
 feature: data/2019-12-01-RavenDBvsMongoDB/logo.png
---

I need a document database. Why? There are areas in my problem generating ([How to calculate 17 billion similarities](/How-to-calculate-17-billion-similarities/)) pet [project cookit](/The-importance-of-running-on-crapp/) that are just asking for a document modelling approach.

Most people will say that this is a straightforward problem to solve:

<div class="center">
 <div class="button" >Slap on MongoDB, and you are ready to go. </div>
</div>

It is NOT a good idea.

<!--MORE-->

# TLTR

This article started as a way to structurize the comparison process but grew a bit more ( just like my [previous comparison](/Choosing-centralized-logging-and-monitoring-system/)). Here is a table of content to give you an overview and make it easier to see the sections:

# Table of content:

- [Why slapping on MongoDB isn't the right idea?](#why-slapping-on-mongodb-isn-t-the-right-idea-)
- [If not MongoDB than what?](#if-not-mongodb-than-what-)
- [MongoDB vs. RavenDB - Fast comparison](#mongodb-vs-ravendb---fast-comparison)
  * [Docker image size](#docker-image-size)
- [Free on-premise tier](#free-on-premise-tier)
    + [What is missing from the free version when compared to the paid one?](#what-is-missing-from-the-free-version-when-compared-to-the-paid-one-)
    + [Paid vs. free comparison.](#paid-vs-free-comparison)
    + [What features RavenDB limits in the free version?](#what-features-ravendb-limits-in-the-free-version-)
    + [What MongoDB limits in the free version?](#what-mongodb-limits-in-the-free-version-)
- [Cloud offerings](#cloud-offerings)
  * [Backups](#backups)
  * [Cloud offering Conclusion](#cloud-offering-conclusion)
- [Clustering model](#clustering-model)
  * [Clustering goals](#clustering-goals)
  * [MongoDB vs. RavenDB clustering](#mongodb-vs-ravendb-clustering)
  * [MongoDB](#mongodb)
    + [MongoDB replication](#mongodb-replication)
    + [MongoDB horizontal scaling](#mongodb-horizontal-scaling)
      - [How does it work from the client's perspective?](#how-does-it-work-from-the-client-s-perspective-)
  * [RavenDB clustering](#ravendb-clustering)
    + [RavenDB replication](#ravendb-replication)
    + [RavenDB horizontal scaling](#ravendb-horizontal-scaling)
  * [Clustering conclusion](#clustering-conclusion)
- [Multi-document transactions](#multi-document-transactions)
  * [What are multi-document transactions?](#what-are-multi-document-transactions-)
  * [MongoDB vs. RavenDB](#mongodb-vs-ravendb)
- [Query Language](#query-language)
  * [MongoDB querying language](#mongodb-querying-language)
    + [RavenDB query language](#ravendb-query-language)
  * [Direct comparison](#direct-comparison)
  * [Query language conclusion](#query-language-conclusion)
- [Indexing](#indexing)
  * [Why is indexing vital in document databases?](#why-is-indexing-vital-in-document-databases-)
  * [RavenDB vs. MongoDB indexes](#ravendb-vs-mongodb-indexes)
    + [MongoDB indexes](#mongodb-indexes)
    + [RavenDB indexes](#ravendb-indexes)
      - [Auto indexes](#auto-indexes)
  * [Indexing comparison](#indexing-comparison)
- [Summary](#summary)
  * [MongoDB](#mongodb-1)
  * [RavenDB](#ravendb)
  * [So, what will it be?](#so--what-will-it-be-)

# Why slapping on MongoDB isn't the right idea?

1. Slapping on any piece of technology into a system is **fundamentally a bad idea**. No matter where You read/heard/saw a recommendation of a product, always consider the **context** of the problem and the recommended solution.
You can read about my context [here](/How-is-cookit-build/), [here](/The-importance-of-running-on-crapp/) and [here where I try to calculate 17 billion similarities](/How-to-calculate-17-billion-similarities/)
I need a document database for storing denormalized entries that will:
- Handle a versatile load - background calculations are very computation heavy
- Have a reasonable learning curve - I want to concentrate on delivering value, not get stuck in the docs for the first week
- Will just work - the less my time it needs, the better
- Not bite me in the least expected moment

2. I worked with MongoDB in the past (not my choice, it was already there), and that wasn't a pleasant ride. To give some examples of problems we had:
- **Querry times** for the same query with different parameters ("Steve" was OK, but "Garry" wasn't) varied by a factor of 100. Up to above 20 seconds on a database that was less than 2GB in size.
- Using [**Robo 3T**](https://robomongo.org) as the default database browser felt like being transported into the year 2000. It was slow, clunky, and tended to crash.
3. **MongoDB lacked multi-document transactions**. When I used MongoDB, it just announced the support for multi-document transactions. With that said, it wasn't encouraged because of significant performance penalties.

The lack of multi-document transactionality didn't seem like a big deal at the start. But after some time, we saw that we were writing more and more code to handle the second, or next, document update fail. In hindsight, this was to expected because:

<div class="center">
 <div class="button" ><b>You can't remove complexity from a system. You can only move it around.</b></div>
</div>

> Now MongoDB supports the option to enable multi-document transactions, but it [has significant performance degradation implications](https://docs.mongodb.com/manual/core/transactions/)). 

> Google also reached the same conclusion. When the database doesn't have multi-document transactions, people will put this logic into the application code. A company that started the NoSQL movement is not using a relational database - Spanner. **Having proper transaction support is cheaper in the long run.**

To sum up the problems:
My last interaction with MongoDB was about two years ago, so not all of them might still be valid. But just checking if they are present without having something to compare it to is a waste of time. Technology doesn't stand still, and new ideas are turned into products all the time.

# If not MongoDB than what?

The title of the post gave it away a bit, but my contender is **RavenDB**. 

<div class="center">
 <div class="button" ><img src="/data/2019-12-01-RavenDBvsMongoDB/saywhat.gif" /></div>
</div>

A valid question here might be *why am I considering Raven when there are other more popular document databases on the market?* A few reasons:

1. The main man behind Raven is Ayende. Also known as Oren Eini, but I am betting the more people will recognize the first "name" or from his [blog](https://ayende.com/blog/) (he has been publishing a post a day since 2004!). Why is this important? He has a track record of collaborating and creating very well thought out, performance-orientated projects that still are one of the best in .NET ecosystem. 
2. A by-product of reading Ayende's blog is the insight into RavenDB development process over the years. What were the critical design decisions and how they matured over time. To point a few:
- Sticking to [multi-document transactions from the start](https://ayende.com/blog/164066/ravendb-acid-base)
- The effort put into making the database require as little Ops as possible with things like [automatically creating indexes based on database usage](https://ravendb.net/docs/article-page/4.1/csharp/indexes/creating-and-deploying#auto-indexes).
- Running on [extremely limited hardware (Raspberry Pi level of limitations)](https://ayende.com/blog/188481-A/running-ravendb-with-low-memory) as a test process.
- Very early development of clustering features in the database.
3. I always wanted to check it out. But for a long time, it never had a free tier, and my curiosity didn't justify the expense.

So, let's compare those two.

# MongoDB vs. RavenDB - Fast comparison 

When looking from a very far distance, those two databases might look very similar. Both are document databases that accept JSON, offer transactions, have indexing options, and scale horizontally. 
Moving a bit closer shows, in many cases, the opposite approach to those areas in both databases.
First, let's take a very high-level overview of capabilities:

|Feature| MongoDB | RavenDB |
|:------|:--------|:--------|
|OS |Windows <br/> Linux<br/> Mac OS <br/> Solaris<br/> | Windows <br/> Linux <br/> Mac OS <br/> Raspberry Pi |
|Official Docker Image| [Linux and Windows-based](https://hub.docker.com/_/mongo) | [Linux and Windows-based](https://hub.docker.com/r/ravendb/ravendb/)
| Schema | No, but there is schema validation*1 | No |
| Support for types | [Partly](https://docs.mongodb.com/manual/reference/operator/query/type/) | [Partly](https://ravendb.net/docs/article-page/4.1/csharp/server/kb/numbers-in-ravendb) |
| Querry language | custom, more [map-reduce like syntax](https://docs.mongodb.com/manual/reference/sql-comparison/) | SQL like [RQL](https://ravendb.net/docs/article-page/4.2/csharp/indexes/querying/what-is-rql)|
| Monitoring | [Free console tools <br/> or paid OpsManager](https://docs.mongodb.com/manual/administration/monitoring/) | [free HTTP endpoint](https://ravendb.net/docs/article-page/4.2/csharp/server/administration/statistics) <br/> free [UI (Studio Manager)](https://ravendb.net/docs/article-page/4.2/csharp/studio/server/server-dashboard)
|SNMP support | [In the paid version](https://docs.mongodb.com/manual/tutorial/monitor-with-snmp/) | [In the paid version](https://ravendb.net/buy) |
| Clustering model | [Master-slave version with Replica Sets or sharding](https://docs.mongodb.com/manual/replication/) | [Multi-master](https://ravendb.net/docs/article-page/4.1/csharp/client-api/cluster/how-client-integrates-with-replication-and-cluster) |
|| | |
|| **Indexes**| |
| Primary indexes | [Yes](https://docs.mongodb.com/manual/indexes/#default-id-index) | Yes |
| Secondary indexes | Yes | Yes |
| Auto indexes | No*2 | [Yes](https://docs.mongodb.com/manual/indexes/#default-id-index)|
| Multiple fields in one index | [Yes (Compound Index)](https://docs.mongodb.com/manual/indexes/#default-id-index)| [Yes (Map indexes)](https://ravendb.net/docs/article-page/4.1/csharp/indexes/map-indexes)|
| Multi-collection indexes | [No](https://docs.mongodb.com/manual/applications/indexes/)| [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/multi-map-indexes)|
|Spatial indexes| [Yes](https://docs.mongodb.com/manual/geospatial-queries/#geospatial-indexes)| [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-spatial-data)|
| Hierarchical indexes | No | [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-hierarchical-data)|
|--|--|--|
| | | |
| | **Cloud offering**| |
| Fully managed? | Yes | Yes |
|Clouds supported| [AWS<br/>Azure<br/>GCP<br/>](https://www.mongodb.com/cloud/atlas) | [AWS<br/>Azure<br/>](https://cloud.ravendb.net/pricing) |
| Consumption plan available | No | No |
| By hour payment? | Yes | Yes |
| Sample price for an hour<br/> (AWS, N. Virginia, 3 nodes, <br/>4 GB of RAM, 20GB storage, 2vCPU) | $0.20 | $0.216 yearly upfront<br/> $0.227 yearly no up-front <br/> $0.239 on demand<br/>
| Backups | [First 1 GB is free<br/>$2.50 per GB/month for the rest](https://www.mongodb.com/cloud/atlas/pricing) | [First 1GB is free<br/>$1.00 per GB/month for the rest](https://cloud.ravendb.net/pricing)
| Backups retention policy | [1 day](https://docs.atlas.mongodb.com/backup/continuous-backups/) | [14 days](https://docs.atlas.mongodb.com/backup/continuous-backups/)
|| ||
|| **Free tier**| |
|Free on-premise | [Yes](https://www.mongodb.com/products/mongodb-enterprise-advanced) | [Yes](https://ravendb.net/buy) |
||**Free Cloud offering**||
| Storage | [0.5 GB](https://www.mongodb.com/cloud/atlas) | [10 GB](https://cloud.ravendb.net/pricing) |
| Memory | [Shared RAM](https://www.mongodb.com/cloud/atlas) | [512 MB](https://cloud.ravendb.net/pricing) |
| CPU | no info | [2 vCPU](https://cloud.ravendb.net/pricing) |

**Legend:**
- **\*1** - MongoDB, from version 3.2 has introduced [schema validation](https://docs.mongodb.com/manual/core/schema-validation/) that allows for some schema verification to be made but doesn't address the performance implications of lack of a schema.
- **\*2** - [it can be done with Mongo Atlas](https://www.mongodb.com/blog/post/improving-mongodb-performance-with-automatically-generated-index-suggestions) but isn't available in the free version and doesn't work out of the box.

## Docker image size

This one is a bit neet peaky, but hear me out. I tend to look at the size of the Docker images. You can call me picky, but having a small Docker image affects a few things:

- It makes continuous deployment faster and simpler
- Smaller containers start faster
- My well being. I know that creating a small image requires some effort. This is why a smaller image feels a bit more polished.

What makes this more interesting is that both databases have Windows container images for Docker (yes, those are a thing). The sizes:

| | Windows | Linux |
|--|---|--|
|MongoDB | 6.07GB <br/>(`mongo:4.2.0-windowsservercore`) | 139.96 MB <br/>(`mongo:4.2.0`) |
|RavenDB | 1.48GB <br/>(`ravendb/ravendb:4.2.4-patch-42020-windows-nanoserver`) | 177.23 MB <br/>(`ravendb/ravendb:4.1.9-patch-41022-ubuntu.18.04-x64`) |
|Difference| MongoDB image is 4.59GB larger | RavenDB is 37,27 MB larger|

The Linux base image size difference is negligible, but the Windows size difference is huge. Why this size difference exists? Different base images. MongoDB uses the Windows **Core** base image. RavenDB uses Windows **Nano**, which is a stripped version of Windows (Microsoft is aiming for it to be below 400MB). I know Windows Docker images aren't on the hype train, and probably will never be. But in some cases, they are the only option, and I hoped that the official image would be better.

> After some additional digging, MongoDB looked into running on Windows Nano, but they are waiting on [multi-stage build support for Windows images](https://github.com/docker-library/official-images/issues/3383). It is a valid argument, but multi-stage builds are [available only from version 17.05 of Docker for Linux images](https://docs.docker.com/develop/develop-images/multistage-build/), and we used Docker before and managed to bypass this limitation :(

# Free on-premise tier

Another area that requires a more in-depth look is the free tier offering. RavenDB, for a long time, discarded the need for a free tier in their product. MongoDB started as a free database and added a paid enterprise version later on.

RavenDB free version comes with [some limitations]((https://ravendb.net/buy):
- max cluster size: 3
- max cores in a cluster: 3 
- max cluster memory usage: 6GB

Those limits are a bit of a pain, especially since MongoDB doesn't have restrictions on the free tier. While I wish those weren't there, I understand why they are present.

But, the limits aren't the only thing that is different between the free versions. There is also what is left out between paid and free for both databases.
 
### What is missing from the free version when compared to the paid one?

The main reason why all free databases have a paid version is to offer support and different licensing options for enterprise users. Both databases moved some features to the enterprise tier:

- Encryption at the storage level
- Snapshot backups
- SNMP (**S**imple **N**etwork **M**anagement **P**rotocol) support

If I could have one option moved to free, that would be storage level encryption. It could save us from a few data leaks.
Now for the differences in missing features.

### Paid vs. free comparison. 

### What features RavenDB limits in the free version?
First of all, RavenDB has [an excellent page comparing the versions](https://ravendb.net/buy)

| Area | Feature name | What it is? | Does it have a MongoDB counterpart? |
|:-|:---|:---|:--|
|Replication | [Pull Replication](https://ravendb.net/docs/article-page/4.2/csharp/studio/database/tasks/ongoing-tasks/pull-replication)| This feature could use a better explanation in the documentation, but [Ayendes blog to the rescue](https://ayende.com/blog/185153-C/ravendb-4-2-features-pull-replication-edge-processing). This is a very interesting feature for synchronizing databases/database clusters that are separated or don't have a permanent connection. <br/>RavenDB - please make this more readable and easier to understand.| No counterpart on MongoDB side | 
|Replication| [External replication](https://ravendb.net/docs/article-page/4.2/csharp/studio/database/tasks/ongoing-tasks/external-replication-task)| The ability to replicate the database outside of the cluster. Useful for backup and recovery scenarios. | No counterpart on MongoDB side |
| Clustering | Dynamic database distribution across the cluster | As I said earlier, RavenDB puts a lot of effort into creating a no-Ops system. And this feature is an excellent example. When one of the nodes in the RavenDB cluster goes down, the cluster manager can distribute the remaining databases to keep a proper number of replicas.| No counterpart on MongoDB side |

### What MongoDB limits in the free version?

The most important missing features when comparing free MongoDB to its paid version (called [MongoDB Enterprise Advanced](https://www.mongodb.com/products/mongodb-enterprise-advanced)) are:

| Area | Feature name | What it is? | Does it have a RavenDB counterpart? | Comment |
|:--|:---|:---|:--|:--|
| Ops | [OpsManger](https://www.mongodb.com/products/ops-manager) | A all-in-one tool for monitoring and managing MongoDB. | For:<br/>- metrics RavenDB has a [metrics HTTP endpoint](https://ravendb.net/docs/article-page/4.2/csharp/server/administration/statistics) exposed by the database itself. <br/> - for visual management, RavenDB has [Management Studio](https://ravendb.net/features/management-studio-gui).
| Performance |[**In-memory storage engine**](https://docs.mongodb.com/manual/core/inmemory/index.html) | A **in-memory only** storage. **Without any persistence.** | RavenDB has [RunInMemory option](https://ravendb.net/docs/article-page/4.2/Csharp/server/configuration/core-configuration#runinmemory). | My first thought was that it would work like <br/>[SQL Server In-Memory Database](https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-database?view=sql-server-ver15) which would be a killer feature.<br/> Without persistence, I don't see this option as a very useful one.|
| Visualization | [Compas](https://www.mongodb.com/products/compass) | Kibana-like system for MongoDB | RavenDB has it's [ Management Studio](https://ravendb.net/features/management-studio-gui) which also offers data visualization options, but I didn't make a direct comparison. |


# Cloud offerings

Both companies offer a very similar model for providing managed cloud services: Select the cloud provider and virtual machine types, and they take care of the rest.
While RavenDB has a very simple configurator, MongoDB Atlas has significantly more knobs and switches.
I tried to do my best in doing an apples to apples comparison and here is what I came up with:

| Configuration | MongoDB cost | RavenDB cost |
|:-----|:----|:------|
|Provider: AWS<br/>Region: N. Virginia<br/>Number of nodes: 3<br/> RAM: 4 GB<br/>Storage 20GB<br/>CPU: 2vCPU | $0.20/h | $0.239/h on demand<br/>$0.227/h yearly no up-front<br/>$0.216/h yearly upfront|
| | | |
|Provider: AWS<br/>Region: N. Virginia<br/>Number of nodes: 3<br/> RAM: 16 GB<br/>Storage 1000GB<br/>CPU: 4vCPU | $1.09/h | $1.109/h on demand<br/>$1.056/h yearly no up-front<br/>$1.003/h yearly upfront|

> Take into account that this is comparing only the hardware, not the performance you get for your money.

## Backups

Why go deep into backups? Read and see. Both services offer the same pricing strategy:

- the first 1GB is free
- anything above that is charged per gigabyte a month.

> MongoDB also offers `Cloud Provider Snapshots` but since it doesn't [guarantee consistency of the backup](https://docs.atlas.mongodb.com/backup/cloud-provider-snapshots/) (what is the point in having backups if we don't know if make sense?) I'm excluding them.

**RavenDB** is very clear how backups work. And they [are mandatory](https://ravendb.net/docs/article-page/4.2/csharp/cloud/cloud-backup-and-restore#the-mandatory-backup-routine) - I like that "we will push You into the pit of success approach":
- full backups are taken every 24 hours
- incremental every 30 minutes
- full backups are kept for 14 days (again this period can be extended, but not reduces - I like that)

With **MongoDB** Continous Backups the policy is a bit murky. The backups are kept for 24 hours and allow for recovering in `a selected point in time within the last 24 hours` (citation taken from the [docs](https://docs.atlas.mongodb.com/backup/continuous-backups/)). Why is this a murky description? Because it lacks information about the granularity of `point in time`. Is it a second, minute or 15 minutes?
There is also an option to enable [Scheduled Snapshots](https://docs.atlas.mongodb.com/backup/continuous-backups/#snapshot-schedule) that look like a counterpart to what RavenDB is offering with some differences in numbers:

| | MongoDB| RavenDB|
|:--|:--|:--|
|Minimum available granularity| 1 hour | 30 minutes |
|Minimum retention period| [2 days](https://docs.atlas.mongodb.com/backup/continuous-backups/#snapshot-schedule) |14 days | 
|Maximum retention period| [5 days, or 30 if they are taken every 24 hours](https://docs.atlas.mongodb.com/backup/continuous-backups/#snapshot-schedule) | [No limit](https://ravendb.net/docs/article-page/4.2/csharp/cloud/cloud-backup-and-restore#the-mandatory-backup-routine) | 
|Price for GB/month | 1.5- 2.5$ | 1$ | 

**That is a 1.5$ a GB/month difference**. A difference in something that will be a significant part of the overall cost of the service. Why do I have such a big issue with this?

1. I don't see any technical reason for such a big difference.
2. It is pointing users into a straightforward cost-saving measure - have fewer backups. This is the reverse direction we should be pointing users.
3. I see this pricing as a way to look cheaper than the service is.

## Cloud offering Conclusion

In a simple comparison, RavenDB is a bit more expensive. But when we take into account, a proper backup behaviour the total pricing will look differently.
As a side note, I will add that I am very happy with the move of database providers to provide managed instances in a selected cloud. It removes, or at least lowers, the need for the company to gain all operation expertise for the selected database. It makes deployments and company politics significantly simpler.

# Clustering model

## Clustering goals

What is clustering? In short, it is how the database behaves when running on multiple servers.
For a more in-depth explanation, [read this here](https://en.wikipedia.org/wiki/Computer_cluster).

Before we go into the clustering behaviour lets define the goals we want to accomplish with clustering:

- **Redundancy** - Being able to operate and not lose data when a node in a cluster fails.
- **Horizontal scaling** - Spread the load on multiple machines.

## MongoDB vs. RavenDB clustering

Clustering is where those two databases show the opposite end of the design spectrum.

- **MongoDB** - uses [replica sets (from version 3.4 up)](https://docs.mongodb.com/v3.4/core/master-slave/) with [database sharding as a method for horizontal scaling](https://docs.mongodb.com/manual/core/sharded-cluster-components/)
- **RavenDB** - is a [multi-master cluster](https://ravendb.net/docs/article-page/4.2/csharp/server/clustering/overview)

Interesting things start when we go deeper.

## MongoDB
### MongoDB replication

MongoDB used to operate in a [master-slave configuration until version 3.4](https://docs.mongodb.com/v3.4/core/master-slave/). Now, master-slave replication was replaced with replica-sets. 
What is the difference between replica-sets and master-slave replication?

Both modes allow for **only one node** to accept all operations and, once they are committed **data is replicated to the slave nodes asynchronously**. Where the replica sets shine is what happens when the master node fails. MongoDB replica sets will do an [automatic failover](https://docs.mongodb.com/manual/replication/#automatic-failover) with automated master election from the shard nodes.

![](/data/2019-12-01-RavenDBvsMongoDB/replica-set-trigger-election.bakedsvg.svg)

Image source: MongoDB documentation

### MongoDB horizontal scaling

MongoDB scales horizontally by [sharding on the database level](https://docs.mongodb.com/manual/sharding/).
Sharding is splitting the data into ** non-overlapping** sub data sets (called chunks in MongoDB) and hosting each chunk on a separate machine. For such an operation to work, we have to define a sharding key what will determine the server which will host the document.
 
![](/data/2019-12-01-RavenDBvsMongoDB/sharding-range-based.bakedsvg.svg)

Sharding can be done in two places:
- **by the client** - the client knows where to put each document.
- **by the database**  - the database is responsible for splitting the data, and it should be transparent to the client.
MongoDB uses the latter approach.

#### How does it work from the client's perspective?

The client connects to an instance of [mongos](https://docs.mongodb.com/manual/reference/program/mongos/) that behaves like a MongoDB database. Mongos is responsible for fetching the shard structure form the [Config Server](https://docs.mongodb.com/manual/core/sharded-cluster-config-servers/), splitting the execution of operations into appropriate servers and combining them at the end.

![](/data/2019-12-01-RavenDBvsMongoDB/sharded-cluster-scatter-gather-query.bakedsvg.svg)

This makes mongos an abstraction layer. Let's look at the benefits and drawbacks of it.

Benefits of database level sharding:

- **Application agnostic**  - the client doesn't know that its queries are shared).
- Simplifies application code.

Disadvantages of database level sharding:

- If we deploy mongos on the application machine, we will need a beefier application server. Deploying it on a database server that will be used by multiple clients creates a **single point of failure and a performance bottleneck**.
- **Sharding key definition can't be changed**. Migrating to a different sharding key specification (selecting different keys to define how data is shared) is, in most cases, [not supported](https://docs.mongodb.com/manual/core/sharding-shard-key/#shard-key-specification). 

    >I don't blame MongoDB for not providing such an option because it is a very compute and network intensive operation that on more massive databases might not be even feasible. 
- Last, but not least. I saw a few approaches to abstracting sharding on the database level, and they never worked. They always leaked. Mostly because of performance.

## RavenDB clustering

### RavenDB replication

RavenDB has a very different approach to clustering. RavenDB cluster is a group of self-organizing nodes that maintains consensus using an implementation of the [RAFT algorithm](https://ravendb.net/docs/article-page/4.1/csharp/server/clustering/rachis/what-is-rachis).

> What is RAFT and how it works is beyond the scope of this article, but a few things to note:
> - it is the standard for reaching consensus in distributed systems.
> - it addresses the problem of a Single Point of Failure in distributed systems. 
> - it has been proven to work.
>
> If You want to know more, an excellent place to start is [here](https://raft.github.io/)

This approach is more complicated, but allows for a few key features:

- [**Dynamic database distribution**](https://ravendb.net/docs/article-page/4.2/csharp/server/clustering/distribution/distributed-database#dynamic-database-distribution). The cluster will rearrange which node is storing which database in case of a cluster node failure, or adding a new node to the cluster.
- **Variable consensus level.** By default, the data is assumed as saved when one node accepts it. Then it is replicated to other master nodes. For special operations, the client can define that he wants to wait for replication to other nodes.

### RavenDB horizontal scaling

[RavenDB doesn't support database level sharding](https://ravendb.net/docs/article-page/4.2/csharp/server/clustering/distribution/distributed-database#sharding). It is on their [roadmap](https://issues.hibernatingrhinos.com/issue/RavenDB-8115) and from the design notes, the approach looks very solid. Taking into account that they already have:
- dynamic database distribution
- RAFT for consensus

We might get auto partitioning [like in Reddis](https://redis.io/topics/partitioning). How would it be different? We won't have to define sharding keys, but let the database distribute the data according to load.

## Clustering conclusion

Before I wrap up this section, let me explain my beef with user-defined sharding (also known as content sharding):

- data has to be split into **non-overlapping** datasets which in some cases might **not be possible or very hard**.
- Selecting the right sharding key is very hard and requires an in-depth knowledge of the *business domain and **future system usage patterns***. Because:
 - **Sharding keys can't be changed easily** This applies to MongoDB, Azure CosmosDB and 
 - **Sharding keys should distribute the data evenly across the cluster nodes**. Otherwise, we end up with a single node that requires vertical scaling (meaning bigger and more expensive machines - the exact thing we wanted to avoid)
 - **Shards have to be monitored.** What once was a good sharding key can become a bad one over time. 

Will RavenDB non-content based sharding be the end-all designs that will fix all of the above? I'm betting no. But it has the potential to solve most of them. Up to this time, I prefer to stay with sharding done by the client.

# Multi-document transactions

## What are multi-document transactions?

First, let's establish what I mean by multi-document transactions. Such a feature has to follow a few rules:

- Expose the ability to execute a list of operations (insert, update, delete) on a set of entities. 
- The changes are applied only if **all operations succeed**. If at least one fails, no changes are applied.
- Until the transaction is committed, the changes aren't visible to other operations.

So how RavenDB and MongoDB compare in this area?

## MongoDB vs. RavenDB

Both support multi-document transactions, but the road to this feature was different. In RavenDB it was a design decision from the start, with MongoDB it was added in version 3.4 with a proper implementation being available just in 4.2. 
Up to version 4.0, the transaction in MongoDB was limited to the total size of 16 MB. This limitation was removed in version 4.2.

# Query Language

From all the differences and features discussed in this post, this one will have the most significant day to day implications.

## MongoDB querying language

MongoDB has a very JSON like approach to building querries. The simplest find querry looks like this:

```javascript
db.inventory.find( { Name: "test" } )
```

Corresponding to SQL query of this:

```sql
Select * from inventory where Name="tests"
```

Looks OK. But where it starts to fall apart is when we want to express things like operators:

```javascript
db.inventory.find( { $or: [ { status: "A" }, { qty: { $lt: 30 } } ] } )
```

This corresponds to this SQL:

```sql
SELECT * FROM inventory WHERE status = "A" OR qty < 30
```

What is nice is the fact that MongoDB managed to keep the language principles simple when dealing with more complex for complex properties in the document. For example this:

```javascript
db.inventory.find( { "instock": { qty: 5, warehouse: "A" } } )
```

Will find documents with the `instock` object equal to `{ qty: 5, warehouse: "A" }`. 

Going back to MongoDB for this article made me remember the most common annoyance with writing MongoDB queries - missing or misplaced braces. 
Now let's see what RavenDb has to offer.

### RavenDB query language

When talking about querying RavenDB, we have to separate two cases - writing in C# and all the other languages. Why? Because RavenDB client leverages C# LINQ expressions (a crossover between SQL and pipes from functional languages) and allows to express queries right in the code.

But not all is lost for not - C# devs. There is RQL which is a mix of SQL and JavaScript looking like this:

```csharp
from Inventory
where Name = 'test'
```

The `from` at the start looks strange, but I can live with this syntax.
Now for the second query:

```csharp
from Inventory
where status = 'A' or qty < 30
```

For me, it is much cleaner than the one in MongoDB. Time for querying complex properties:

```csharp
from Inventory
where instock.qty = 5 and instock.warehouse = 'A'
```

## Direct comparison

| MongoDB | RavenDB |
|:----|:---|
|``` db.inventory.find( { Name: "test" } )``` | ```from Inventory where Name = 'test'```|
|``` db.inventory.find( { $or: [ { status: "A" }, { qty: { $lt: 30 } } ] } )``` | ```from Inventory where status = 'A' or qty < 30```|
|``` db.inventory.find( { "instock": { qty: 5, warehouse: "A" } } )``` | ```from Inventory where instock.qty = 5 and instock.warehouse = 'A' ```|


## Query language conclusion

I know this is a matter of taste, but SQL is the most popular language for querying data. Having something similar to it makes the developer more productive faster.
Some will say that custom language in MongoDB allows for unique functionalities and that SQL is not well suited for document databases. I agree with this, but only partially. Multiple document databases expose SQL like querying language, and some migrated from custom to syntax to one more similar to SQL without losing unique functionalities.

# Indexing

## Why is indexing vital in document databases?

We all know that database indexing is essential. For decades they were the most effective ways to optimize relational databases. But there is one very distinctive difference between relational and document databases (MongoDB and RavenDB in our case). The lack of a schema. Why does this matter?

When we query over a **non-indexed** column in a **relational database**, it doesn't have to read the whole file representing the table. It knows the table structure so it can calculate the file offsets and read only the necessary file fragments where this property is stored. Not ideal but works quite good.

When we query over a ** non-indexed** property in a **schema-less document database** the database doesn't know the structure. It means that it has to deserialize each document and check if the requested property exists and what is its value. This means a higher disc, CPU and RAM usage.

## RavenDB vs. MongoDB indexes

### MongoDB indexes

MongoDB has a very standard set of indexes:

- [Single field](https://docs.mongodb.com/manual/core/index-single/) - for indexing one field
- [Compound index](https://docs.mongodb.com/manual/core/index-compound/) - for indexing multiple properties
- [Multikey index](https://docs.mongodb.com/manual/core/index-multikey/) - for indexing array items
- [Geospatial Index](https://docs.mongodb.com/manual/core/geospatial-indexes/) - for GIS operations
- [Text index](https://docs.mongodb.com/manual/core/index-text/) - for text searches. It uses Lucene, so you get full-text search like in Elastic Search or Solr.

    > MongoDB has a limitation that one collection can have only one text index.

As an addition, indexes can have additional properties:

- [Unique Indexes](https://docs.mongodb.com/manual/core/index-unique/) - for guaranteeing uniqueness of the features
- [Partial Indexes](https://docs.mongodb.com/manual/core/index-partial/) - they give the ability to filter the documents that will be indexed.
- [Sparse Indexes](https://docs.mongodb.com/manual/core/index-sparse/) - they will only index documents that have the selected property after version 3.2 replaced by Partial Indexes indexes.
- [TTL Indexes](https://docs.mongodb.com/manual/core/index-ttl/) - allows defining an automatic document removal period. 
    
    > A useful option, but why is it on an index?

It is a very standard and robust set of indexes. Nothing groundbreaking, but OK.

### RavenDB indexes

RavenDB has a fundamentally different design approach to indexes. They are represented and declared as a user-defined function. Such a function is passed to RavenDB, and it takes care of the indexing and maintaining the index. 
This design decision leads to exciting possibilities like:

- [Combining fields in the index (FirstName + ' ' + LastName )](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-indexes#combining-multiple-fields-together)
- [Executing calculations](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-reduce-indexes) (if it can be expressed as a function it can be used in an index)
- [Aggregating documents before indexing](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-reduce-indexes#reduce-results-as-artificial-documents)
- [Having multiple entries in an index for a document](https://ravendb.net/docs/article-page/4.2/csharp/indexes/fanout-indexes) - this is very useful when we want to flatten the object structure for indexing.
- [Perform queries in the indexing function](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-related-documents#example-ii)
- [Indexing hierarchical data](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-hierarchical-data). I like this feature because executing hierarchical queries without support from the database is tough. In most cases requires special data modelling.

    > I wrote more on modelling hierarchical data [here](/How-to-model-hierarchical-data-in-noSQL-datababases/).

I am very impressed by the power that RavenDB indexes offer. They are pushing the user into two behaviours:

- For complex queries, separate the write model from the read model - CQRS. Something that we all know we should do, but don't always do.
- Always try to query over an index.

#### Auto indexes

The push to always try to query over an index is supported by the last feature that I will discuss - [auto-indexing](https://ravendb.net/docs/article-page/4.2/csharp/indexes/creating-and-deploying#auto-indexes). 
RavenDB can monitor the queries and automatically create indexes. It could be a very dangerous option because indexes generate an additional load on the server. But RavenDB also can delete unused indexes. 
Why do I like this feature? Adding each new component to the system means one additional element to worry about, monitor and maintain. Auto indexing won't zero this overhead but anything that will decrease it is a welcomed addition.

## Indexing comparison

| Option| MongoDB | RavenDB |
|:---|:---|:---|
| Primary indexes | [Yes](https://docs.mongodb.com/manual/indexes/#default-id-index) | Yes |
| Secondary indexes | Yes | Yes |
| Auto indexes | No*2 | [Yes](https://docs.mongodb.com/manual/indexes/#default-id-index)|
| Multiple fields in one index | [Yes (Compound Index)](https://docs.mongodb.com/manual/indexes/#default-id-index)| [Yes (Map indexes)](https://ravendb.net/docs/article-page/4.1/csharp/indexes/map-indexes)|
| Spatial indexes | [Yes (GeoSpatial Index)](https://docs.mongodb.com/manual/core/geospatial-indexes/)| [Yes (Spatial Data)](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-spatial-data)|
| Full-text indexes | [Yes (Text Index)](https://docs.mongodb.com/manual/core/index-text/)| [Yes (Full-Text Search)](https://ravendb.net/docs/article-page/4.2/csharp/indexes/using-analyzers#full-text-search)|
| Multi-collection indexes | [No](https://docs.mongodb.com/manual/applications/indexes/)| [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/multi-map-indexes)|
| Hierarchical indexes | No | [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/indexing-hierarchical-data)|
| Perform calculations or operations on indexes | No | [Yes(Map-Reduce Indexes)](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-reduce-indexes) | 
| Convert data during indexing | No | [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-indexes#combining-multiple-fields-together) |
| Aggregate data in indexes | No | [Yes](https://ravendb.net/docs/article-page/4.2/csharp/indexes/map-reduce-indexes#reduce-results-as-artificial-documents)|

**Legend:**
- **\*2** - [it could be done with Mongo Atlas](https://www.mongodb.com/blog/post/improving-mongodb-performance-with-automatically-generated-index-suggestions) but isn't available in the free version and doesn't work out of the box

# Summary

<a name="MongoDB"></a>
![MongoDB](/data/2019-12-01-RavenDBvsMongoDB/mongodb.png){: .logo}

## MongoDB

**The good:**

- Free version without a database or used CPU/memory limits.
- Solid documentation

**The bad:**

- The lack of SQL like syntax for query operations makes for a steep learning curve.
- Robo3T is better than it used to be, but still lacking.

**The ugly:**

- What is with the MongoDB Atlas backup pricing?
- That Windows Docker image could be smaller.

<a name="RavenDB"></a>
![RavenDB](/data/2019-12-01-RavenDBvsMongoDB/ravendb.png){: .logo}

## RavenDB

**The good:**

- Multiple indexing options.
- SQL-like RQL (**R**aven **Q**uery **L**anguage) provides a smooth learning curve.
- **Raven Studio** for querying and managing the database is just a substantial addition to the product. Way better than Robot3T
- A clear design goal to push the user towards proper behaviour

**The bad:**

- The limits in the free version could be higher. For me, they won't be an issue, but I can imagine them deter some people. Maybe a different licencing model?

**The ugly:**

- <s>The documentation is lacking and is very uneven how deep is each section.</s>[There is an excellent book on the website that goes in-depth and beyond](https://ravendb.net/learn/inside-ravendb-book/reader/4.0/1-welcome-to-ravendb). Also not a fan of the dark theme, but I know I'm in the minority.

## So, what will it be?

This comparison is far from exhaustive, but I have some conclusions. I will probably make a performance comparison of those two. For now, RavenDB feels like a solid, well thought out product with even more potential (e.g., clustering) for delivering new features that will build on the previous design decisions. 

<style>
div.entry-content .logo{
 height:150px;
}
</style>