---
layout: post
title: What is the simplest database?
description: "You almost can't go simpler than key-value databases, but even them are more complex than they seem."
modified: 2017-03-20
tags: [databases, architecture, key-value, analysis, comparison]
series: "databases"
image:
  feature: data/2017-03-20-What-is-the-simplest-database/logo.jpg
---

The world of databases is a fascinating topic. It is very diverse. Many of them are extremely complex systems, but there are also very simple ones. There are the general purpose ones, and ones that do only one thing good, but they do it excelent. Despite all of this we tend to pick them just like we order food in a restaurant:

- I'll take the same as last time. It wasn't ideal for what I wanted, but I could pick worse.
- Hmm... Everyone is taking this one, so I'll take it also.

Well, maybe it is time to dig deeper into it?

<!--MORE-->

## Preface 

I'm writing this post in addition to my [You are using the wrong database!](/speaking/cfp/You-are-using-the-wrong-database!/) talk which intention is to show:

- how important is picking the right database and how strongly it affects the whole system
- How diverse is the world of databases.
- Why the most common criterium for choosing: *"I'll use what I know"* sucks, putting it lightly.

## Definition

Here is where a copy and paste from Wikipedia typically happens, but let's create a definition based a more look and feel approach and let's define simple requirements.
I divided them into two parts: **must-haves** and **should-haves**. Here we go:

### Must haves

Those points are what, for me, defines a database. The core functionalities that make a product a database:

- **ability to reliably persist data** - kind of a no-brainer, but this paragraph is just for that. 
- **ability to reliably retrieve data** - there is little use for a database that can only accept data but can't retrieve it. 
- **ability to delete data** - the first point defines `INSERT`, the second a `SELECT` operation, so all that is missing is a `DELETE`

Only three points? Yes, but remember, we are talking about the must haves.

{% include /newsletter.html %}

### Should-haves

So this is where I put all the theoretical features mumbling? Not exactly, here are my **should-haves**:

- **ability to query data** - how this one differs from the must-haves ability to retrieve data? There we identified the data using a single key. Here we require the capacity to return a list of data that meets certain parameters. Think of it as the conditions on columns in the `WHERE` clause from SQL.
- **ability to update data** - this, in theory, could be achieved by deleting and inserting a new record, but this implementation fails quite fast when taking into account a bit more advanced features (deleting and inserting would change the auto-generated ID, or could fail if the row was referenced). 
- **has transactions** - I am not talking here about the more advanced things like isolation levels or distributed transactions, but the simple fact that if something fails while executing an update the database won't get corrupted.

## The simplest database

Go on have a guess. What is the simplest database that fulfills all the must-haves and almost all should-haves?

Are You sure You know? Think again, but if You are sure 

<div class="center" id="wrapper" >
    <div type="button" class="button btn" onclick="show()" >CLICK HERE if You know </div>
</div>

<div class="entry-image-index" style="background:url('/data/2017-03-20-What-is-the-simplest-database/files.png') no-repeat scroll center center; background-size: cover;"> </div>


### File system is the simplest database

Did You get it right? Do You believe it? Let's got through the lists.
**Must haves:**

- [x] **ability to reliable persist data** - calling `fsync` will make sure that the file was written to the hard drive and the hard drive is what we think when talking about persistent storage.  
- [x] **ability to reliably retrieve data** - You can read the contents of a file.
- [x] **ability to delete data** - once again, a simple delete.

**Should haves:**
  
- [x] **ability to update data** - We can update a file right? We can even do a partial update thanks to the ability to start writing from a certain index.
- [x] **has transactions** - A pass? Files systems have transactions? Yes. [Windows even has support for distributed transactions](https://msdn.microsoft.com/en-us/library/windows/desktop/aa363764(v=vs.85).aspx). This means that you can combine saving a file with an update in a database on an external server. Anyone who worked with distributed transaction knows that they should be avoided. That said, in some cases, it is not possible.
- [x] **ability to query data** - We can query files by their name, content and directory structure. This is more that some real databases offer.

This post is a preface for a more advanced series covering database mechanics and the variety of database types. If You are interested, subscribe to [RSS](https://indexoutofrange.com/feed.xml), or follow on [Twitter](https://twitter.com/maklipsa)

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script>
    $("#wrapper").show();
    $("#wrapper").nextAll().hide();
    function show(){
        $("#wrapper").nextAll().show();
        $("#wrapper").hide();
    }
</script>