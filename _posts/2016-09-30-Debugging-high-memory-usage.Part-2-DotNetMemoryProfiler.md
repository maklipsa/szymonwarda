---
layout: post
title: Debugging high memory usage. Part 2 - .NET Memory Profiler
description: "Analysis of high memory usage can be tricky. This post describes how to analyze a memory dump with .NET Memory Profiler and how to look for the cause why the application is allocating co much memory."
modified: 2016-09-30
tags: [.NET, memory dump, .NET Memory Profiler]
series: "Debugging high memory usage"
image:
  feature: data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/logo.png
---

Diagnosing high memory usage can be tricky, here is the second part of how I found what was hogging to much memory in our system.
In the [previous post](/Debugging-high-memory-usage.Part-1-ProcDump/) I've wrote how to create a memory dump and how many possibilities of catching just the right moment for it ProcDump has. 
When trying to analyze memory leaks, or high memory usage (not necessary meaning a leak) we have a few ways to approach it:
<!--MORE-->

### Attach a debugger

There are many problems with this approach, to name a few:

- it has to be done on the machine where the memory outrage has happened (probably a test server). And there Visual Studio shouldn't be installed.
- when debugging an IIS managed process it is being stopped. While the process is stopped it won't respond to IIS [ping requests](https://blogs.msdn.microsoft.com/gaurav/2015/01/16/the-web-server-process-that-was-being-debugged-has-been-terminated-by-internet-information-services-iis-this-can-be-avoided-by-configuring-application-pool-ping-settings-in-iis/) (they can be turn off, but it is a good practice to have them on). This in effect will make IIS believe that that the process is hanging and restart it. And there goes our debugging session :(  
- debugging a multithreaded application handling multiple incoming requests will lead to breakpoints being triggered by multiple requests, not just the one being debugged
- step by step debugging doesn't give a view of the memory allocated 

To sum up, this is not a good way to approach the problem.

### Attach an online profiler
Products like [Redgate ANTS Profiler](http://www.red-gate.com/products/dotnet-development/ants-memory-profiler/), [JetBrains dotMemory](https://www.jetbrains.com/dotmemory/features/) can attach to a process and show current GC generation sizes, the paste of new memory being allocated, and compare memory between two points in time (snapshots). While those features are great when profiling and optimizing, they are not that useful when trying to diagnose what has allocated the memory.

### Offline memory analyzers
To clarify, by offline I mean programs that can read a memory dump ( the [previous post](http://indexoutofrange.com/Debugging-high-memory-usage.Part-1-ProcDump/) covers one of the methods how to create a memory dump). This criteria leaves us with not that many programs to choose from. Online profilers mentioned above can't read a memory dump. From my knowledge at this point we can choose from:

- [WinDbg](https://msdn.microsoft.com/en-us/library/windows/hardware/ff551063(v=vs.85).aspx)
- [.NET Memory Profiler from SciTech Software AB](http://memprofiler.com/) 

The first one is the all powerful big boys profiler with text commands and text based gui. It has the power and the speed that none other profiler has, but
![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/spyderman.jpg)

Another, more important in this cases, thing lacking is the ability to show dependencies between objects and memory they allocated. So let's look at what .NET Memory profiler can do.

{% include /newsletter.html %}

## .NET Memory Profiler
> .NET Memory Profiler can have a tendency to crash after few minutes, sometimes even in less then one. As strange as it seams restarting the computer removes the problem. This happened to me 3 times.

First let's load the dump file with `File > Import memory dump...`.
This opens a nice import window with a few options and data to fill:

- `Include instance addresses` - in our case not important. I' m not planing on reading the dump in search of individual objects.  
- `Collect instance data` - this gives the ability to view values of fields and objects. Very nice feature, but at the first run I usually try to get a high-level look at the objects in memory so this is not needed for now.

After pushing Start another window will appear asking for `mscordacwks.dll` and `sos.dll`. **You need to take those files from the machine on which the dump was made.** .NET Memory Profiler tries to give hints where to find them, but the exact framework version can be slightly different (4.5 instead of 4.6.1 etc).

After some time (depending from the dump size) the main window will appear:

![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/MemProfiler_step01.png)

So let's look what we have here. While this screen alone can give the answer to someone knowing the application, let's go through it in investigative mode. What we see immediately is that the main memory holder is `StatefulPersitanceContext` from NHibernate. With 28 instances it is holding almost 2 Gigs of memory.
So lets double click on it and go into details. And we see this:

![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/MemProfiler_step02.png)


The window on the left shows the current instances and info about them. One instance is responsible for most used memory. So let's drill into it. Double click and here we go.

![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/MemProfiler_step03.png)

Did You notice that the graph on the right changed? It is showing dependency graphs for the currently selected instances.
What can be seen is that `Session` is keeping hold of `Document` entity, which has a few collections on its own.
The next object referring to this session is on the right side of the graph:

![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/MemProfiler_step04.png)

So `AutoCloseDocumentService` in `CloseSettledDocuments` is holding to this large session, and the session holds `Document` entity.
So let's get back to the first screen and see just how many `Document` entities there are:

![](/data/2016-09-30-Debugging-high-memory-usage.Part-2-dot-net-memory-profiler/MemProfiler_step05.png)

Yup. Over 301 thousand root entities in one NHibernate session. Just to be sure let's look at the `CloseSettledDocuments` function:

```csharp
    public void CloseSettledDocuments()
    {
        var settledDocumentsToBeClosed = GetApprovedDocuments()
        ...

        foreach (var document in settledDocumentsToBeClosed)
            CloseDocument(document);
    }
```

and a peek into `GetApprovedDocuments`:

```csharp
    public IList<Document> GetApprovedDocuments(){
        return _session.QueryOver<Document>().ToList();
    }
```

So we listed 301 thousand documents and processed each one independently. Classic n+1 problem that escalated because of large amount of data.

