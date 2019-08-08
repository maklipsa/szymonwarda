---
layout: post
title: The cost of garbage collection
description: "A try to measure the cost of generation 0, 1 and 2 garbage collection"
modified: 2016-07-12
tags: [.NET, performance, GC, Garage collection, benchmark, GC.Collect, NBench]
series: "The cost of garbage collection"
image:
  feature: data/2016-07-12-The-cost-of-garbage-collection/logo.png
---

**Update**
There is a error in the first version of this code, and the tests are in fact always operating in a situation that almost all object are in generation 2. The answer is in the [next post](/The-cost-of-garbage-collection.Part-2-rectification)  
 
In the [previous post](http://indexoutofrange.com/GC-can-kill-You-Practical-GC-performance-counters-in-NET/) I've promised to write how to have differentiate the number of workers in Hangfie, but in the comments Michał asked one interesting question - "Is generation 1 collection more expensive then generation 0 collection?". Going further how does generation 2 collection fit into it?
<!--MORE-->

I always believed that running `GC.Collect` is more expensive the deeper we go. So `GC.Collect(0)` is the least expensive, and `GC.Collect(2)` is most expensive. This opinion was reinforced by articles I remember reading and general opinion that .NET is optimized for fast young object collection.

But after a moment of thought I came to conclusion that the same/very similar algorithm could be used for every garbage collection generation. I started a conversation with my team at work, and after a while they came to more or less the same conclusion: 

> We don't know. And to make matters worse there seem to be articles stating opposite opinions in this topic.  

The only thing left was to check.<br/> 
To check I needed couple of things:


## 1. Large number of object that can be collected.

I've assumed that increasing the number of objects will influence garbage collection time - this is quite logical assumption. One thing to have in mind is that those **have to be objects** (instances of classes) **not structs**. Why? Because structs and classes are collected in different ways. Classes are collected by counting references during `GC.Collect`, and structs, since you can't have a reference to it, are collected when they loose scope, or during collection of object that contains it. More on this can be read for example [here](https://www.simple-talk.com/dotnet/.net-framework/5-tips-and-techniques-for-avoiding-automatic-gc-collections/)
So my class looks like this:

```csharp
private class MyGCTestClass
{
    private readonly string Text;

    public MyGCTestClass(string text)
    {
        Text = text;
    }

    public MyGCTestClass(MyGCTestClass source)
    {
        Text = source.Text;
    }
}
```

And generating code looks like this:
    
```csharp
private List<MyGCTestClass> GenerateObjects(long count)
{
    var ret = new List<MyGCTestClass>();
    for (var i = 0; i < count; i++)
    {
        ret.Add(new MyGCTestClass(Guid.NewGuid().ToString()));
    }
    return ret;
}
```

## 2. A way to trigger garbage collection
Since [.NET has two garbage collectors (client and server)](https://blogs.msdn.microsoft.com/dotnet/2012/07/20/the-net-framework-4-5-includes-new-garbage-collector-enhancements-for-client-and-server-apps/) and I wanted to measure time impact so using the blocking one (client) was the only logical choice. A quick entry in [app/web.config](https://msdn.microsoft.com/en-us/library/ms229357(v=vs.110).aspx):

```xml
<configuration>
    <runtime>
        <gcServer enabled="false" />
    </runtime>
</configuration>
```
 
Also `GC.Collect` has several overloads. The [four parameter overload](https://msdn.microsoft.com/en-us/library/dn906200(v=vs.110).aspx) enables to:

-  set the collection as blocking
-  force garbage collection to actually execute
-  force compacting (So not only marking objects for deletion, [but also moving the rest together to minimize memory fragmentation](https://msdn.microsoft.com/en-us/library/ee787088(v=vs.110).aspx) )
The call will look like this:

```csharp
GC.Collect(generationNumber, GCCollectionMode.Forced, true, true);
```

## 3. A way to check how many times collection was executed

Because .NET runtime can trigger garbage collection on its own I had to be sure that the only garbage collection was that triggered by me.  
This can be done by using [`GC.RegisterForFullGCNotification`](https://msdn.microsoft.com/en-us/library/system.gc.registerforfullgcnotification(VS.100).aspx), but performance benchmarks like [NBench](https://github.com/petabridge/NBench) or  [BenchmarkDotNet](https://github.com/PerfDotNet/BenchmarkDotNet) have it nicely wrapped. I've decided to go with NBench and it's `GcTotalAssertion` attribute.

So my test class looked like this:

```csharp
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using NBench;

namespace Tests
{
    public class GCCollection
    {
        private readonly string[] _messages =
        {
            "Gen 0 ticks:       ",
            "Gen 0+1 ticks:     ",
            "Gen 0+1+2 ticks:   "
        };

        private List<MyGCTestClass> _list;

        [PerfSetup]
        public void Setup(BenchmarkContext context)
        {
            _list = GenerateObjects(20*1000*1000);
            Console.WriteLine("Objects generated.");
            GC.Collect(2, GCCollectionMode.Forced, true,true);/*To be sure everything that can will be collected.*/
        }

        [PerfBenchmark(Description = "Gen 0 collection", NumberOfIterations = 1, RunMode = RunMode.Iterations,TestMode = TestMode.Test)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen0, MustBe.ExactlyEqualTo, 1d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen1, MustBe.ExactlyEqualTo, 0.0d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen2, MustBe.ExactlyEqualTo, 0.0d)]
        public void Gen0Collection()
        {
            _list = null;

            var sw = Stopwatch.StartNew();

            RunGCAndCheck(0, sw);/* Run collect for gen 0 - collect everything.*/
        }


        [PerfBenchmark(Description = "Gen 1 collection", NumberOfIterations = 1, RunMode = RunMode.Iterations,TestMode = TestMode.Test)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen0, MustBe.ExactlyEqualTo, 2.0d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen1, MustBe.ExactlyEqualTo, 1.0d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen2, MustBe.ExactlyEqualTo, 0.0d)]
        public void Gen1Collection()
        {
            var sw = Stopwatch.StartNew();
            RunGCAndCheck(0, sw);/* Can't collect anything. Move it to gen 1.*/

            _list = null;
            RunGCAndCheck(1, sw);/* Run collect for gen 0 - it is empty. Run gen 1 collection - collect everything.*/
        }

        [PerfBenchmark(Description = "Gen 2 collection", NumberOfIterations = 1, RunMode = RunMode.Iterations,TestMode = TestMode.Test)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen0, MustBe.ExactlyEqualTo, 3.0d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen1, MustBe.ExactlyEqualTo, 2.0d)]
        [GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen2, MustBe.ExactlyEqualTo, 1.0d)]
        public void Gen2Collection()
        {
            var sw = Stopwatch.StartNew();

            RunGCAndCheck(0, sw);/* Can't collect anything. Move it to gen 1.*/

            RunGCAndCheck(1, sw);/* Run collect for gen 0 - it is empty. Run gen 1 collection - collect the list elements.*/

            _list = null;
            RunGCAndCheck(2, sw);/* Run collect for generation 0 - it is empty. Run collect for generation 1 - it is empty. Run collect for generation 2 - collect everything.*/
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private void RunGCAndCheck(int generationNumber, Stopwatch sw)
        {
            sw.Restart();
            GC.Collect(generationNumber, GCCollectionMode.Forced, true,true);
            Console.WriteLine(_messages[generationNumber] + sw.ElapsedTicks);
        }

        private List<MyGCTestClass> GenerateObjects(long count)
        {
            var ret = new List<MyGCTestClass>();
            for (var i = 0; i < count; i++)
            {
                ret.Add(new MyGCTestClass(Guid.NewGuid().ToString()));
            }
            return ret;
        }

        private class MyGCTestClass
        {
            private readonly string Text;

            public MyGCTestClass(string text)
            {
                Text = text;
            }

            public MyGCTestClass(MyGCTestClass source)
            {
                Text = source.Text;
            }
        }
    }
}
```

Some things to point out:

- `RunGCAndCheck` has `[MethodImpl(MethodImplOptions.AggressiveInlining)]` to inline the method and thus minimize the chance garbage collection will be called after it exits.
- `Setup` will be called before every test because of the `PerfSetup` attribute.
- Running `GC.Collect(n)` will cause garbage collection on all generation up to and with n-th generation.

{% include /newsletter.html %}

# Running the test in NBench

First thing to note is that NBench requires it's own runner (it is avilable on [nuget](https://www.nuget.org/packages/NBench.Runner/)).
The second is that it runs every test twice as a warm up to minimize for such things like time spend by .NET allocating memory, and JITing the code.

## Gen0Collection (objects collected in generation 0 collection):

```bash
------------ STARTING Tests.GCCollection+Gen0Collection ----------
Objects generated.
Gen 0 ticks:       21257
Objects generated.
Gen 0 ticks:       42541
--------------- BEGIN WARMUP ---------------
Elapsed: 00:00:00.0171519
TotalCollections [Gen0] - collections: 1,00 ,collections: /s 58,30 , ns / collections: 17 151 979,67
TotalCollections [Gen1] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 17 151 979,67
TotalCollections [Gen2] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 17 151 979,67
--------------- END WARMUP ---------------

Objects generated.
Gen 0 ticks:       47949
--------------- BEGIN RUN ---------------
Elapsed: 00:00:00.0192217
TotalCollections [Gen0] - collections: 1,00 ,collections: /s 52,02 , ns / collections: 19 221 705,61
TotalCollections [Gen1] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 19 221 705,61
TotalCollections [Gen2] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 19 221 705,61
--------------- END RUN ---------------

--------------- RESULTS: Tests.GCCollection+Gen0Collection ---------------
Gen 0 collection
--------------- DATA ---------------
TotalCollections [Gen0]: Max: 1,00 collections, Average: 1,00 collections, Min: 1,00 collections, StdDev: 0,00 collections
TotalCollections [Gen0]: Max / s: 52,02 collections, Average / s: 52,02 collections, Min / s: 52,02 collections, StdDev / s: 0,00 collections

TotalCollections [Gen1]: Max: 0,00 collections, Average: 0,00 collections, Min: 0,00 collections, StdDev: 0,00 collections
TotalCollections [Gen1]: Max / s: 0,00 collections, Average / s: 0,00 collections, Min / s: 0,00 collections, StdDev / s: 0,00 collections

TotalCollections [Gen2]: Max: 0,00 collections, Average: 0,00 collections, Min: 0,00 collections, StdDev: 0,00 collections
TotalCollections [Gen2]: Max / s: 0,00 collections, Average / s: 0,00 collections, Min / s: 0,00 collections, StdDev / s: 0,00 collections

--------------- ASSERTIONS ---------------
[PASS] Expected TotalCollections [Gen0] to must be exactly 1,00 collections; actual value was 1,00 collections.
[PASS] Expected TotalCollections [Gen1] to must be exactly 0,00 collections; actual value was 0,00 collections.
[PASS] Expected TotalCollections [Gen2] to must be exactly 0,00 collections; actual value was 0,00 collections.

------------ FINISHED Tests.GCCollection+Gen0Collection ----------
```

The test itself is the part after `END WARMUP`. And according do this run generation 0 collection collecting all the objects lasts 47949 ticks. 

## Gen1Collection (objects collected in generation 1 collection)

```bash
------------ STARTING Tests.GCCollection+Gen1Collection ----------
Objects generated.
Gen 0 ticks:       45994
Gen 0+1 ticks:     546
Objects generated.
Gen 0 ticks:       45196
Gen 0+1 ticks:     522
--------------- BEGIN WARMUP ---------------
Elapsed: 00:00:00.0194638
TotalCollections [Gen0] - collections: 2,00 ,collections: /s 102,75 , ns / collections: 9 731 939,08
TotalCollections [Gen1] - collections: 1,00 ,collections: /s 51,38 , ns / collections: 19 463 878,17
TotalCollections [Gen2] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 19 463 878,17
--------------- END WARMUP ---------------

Objects generated.
Gen 0 ticks:       47584
Gen 0+1 ticks:     472
--------------- BEGIN RUN ---------------
Elapsed: 00:00:00.0206490
TotalCollections [Gen0] - collections: 2,00 ,collections: /s 96,86 , ns / collections: 10 324 530,97
TotalCollections [Gen1] - collections: 1,00 ,collections: /s 48,43 , ns / collections: 20 649 061,95
TotalCollections [Gen2] - collections: 0,00 ,collections: /s 0,00 , ns / collections: 20 649 061,95
--------------- END RUN ---------------

--------------- RESULTS: Tests.GCCollection+Gen1Collection ---------------
Gen 1 collection
--------------- DATA ---------------
TotalCollections [Gen0]: Max: 2,00 collections, Average: 2,00 collections, Min: 2,00 collections, StdDev: 0,00 collections
TotalCollections [Gen0]: Max / s: 96,86 collections, Average / s: 96,86 collections, Min / s: 96,86 collections, StdDev / s: 0,00 collections

TotalCollections [Gen1]: Max: 1,00 collections, Average: 1,00 collections, Min: 1,00 collections, StdDev: 0,00 collections
TotalCollections [Gen1]: Max / s: 48,43 collections, Average / s: 48,43 collections, Min / s: 48,43 collections, StdDev / s: 0,00 collections

TotalCollections [Gen2]: Max: 0,00 collections, Average: 0,00 collections, Min: 0,00 collections, StdDev: 0,00 collections
TotalCollections [Gen2]: Max / s: 0,00 collections, Average / s: 0,00 collections, Min / s: 0,00 collections, StdDev / s: 0,00 collections

--------------- ASSERTIONS ---------------
[PASS] Expected TotalCollections [Gen0] to must be exactly 2,00 collections; actual value was 2,00 collections.
[PASS] Expected TotalCollections [Gen1] to must be exactly 1,00 collections; actual value was 1,00 collections.
[PASS] Expected TotalCollections [Gen2] to must be exactly 0,00 collections; actual value was 0,00 collections.

------------ FINISHED Tests.GCCollection+Gen1Collection ----------
```

The difference between 47584 ticks for generation 0 and 472 ticks for generation 1 collection is big (more than 100 times), but keep reading because the best is yet to come.

## Gen2Collection (objects collected in generation 2 collection)

```bash
------------ STARTING Tests.GCCollection+Gen2Collection ----------
Objects generated.
Gen 0 ticks:       46034
Gen 0+1 ticks:     559
Gen 0+1+2 ticks:   1461791
Objects generated.
Gen 0 ticks:       37438
Gen 0+1 ticks:     451
Gen 0+1+2 ticks:   793937
--------------- BEGIN WARMUP ---------------
Elapsed: 00:00:00.3300270
TotalCollections [Gen0] - collections: 3,00 ,collections: /s 9,09 , ns / collections: 110 009 021,88
TotalCollections [Gen1] - collections: 2,00 ,collections: /s 6,06 , ns / collections: 165 013 532,82
TotalCollections [Gen2] - collections: 1,00 ,collections: /s 3,03 , ns / collections: 330 027 065,65
--------------- END WARMUP ---------------

Objects generated.
Gen 0 ticks:       36631
Gen 0+1 ticks:     524
Gen 0+1+2 ticks:   1358065
--------------- BEGIN RUN ---------------
Elapsed: 00:00:00.5528463
TotalCollections [Gen0] - collections: 3,00 ,collections: /s 5,43 , ns / collections: 184 282 119,04
TotalCollections [Gen1] - collections: 2,00 ,collections: /s 3,62 , ns / collections: 276 423 178,56
TotalCollections [Gen2] - collections: 1,00 ,collections: /s 1,81 , ns / collections: 552 846 357,12
--------------- END RUN ---------------

--------------- RESULTS: Tests.GCCollection+Gen2Collection ---------------
Gen 2 collection
--------------- DATA ---------------
TotalCollections [Gen0]: Max: 3,00 collections, Average: 3,00 collections, Min: 3,00 collections, StdDev: 0,00 collections
TotalCollections [Gen0]: Max / s: 5,43 collections, Average / s: 5,43 collections, Min / s: 5,43 collections, StdDev / s: 0,00 collections

TotalCollections [Gen1]: Max: 2,00 collections, Average: 2,00 collections, Min: 2,00 collections, StdDev: 0,00 collections
TotalCollections [Gen1]: Max / s: 3,62 collections, Average / s: 3,62 collections, Min / s: 3,62 collections, StdDev / s: 0,00 collections

TotalCollections [Gen2]: Max: 1,00 collections, Average: 1,00 collections, Min: 1,00 collections, StdDev: 0,00 collections
TotalCollections [Gen2]: Max / s: 1,81 collections, Average / s: 1,81 collections, Min / s: 1,81 collections, StdDev / s: 0,00 collections

--------------- ASSERTIONS ---------------
[PASS] Expected TotalCollections [Gen0] to must be exactly 3,00 collections; actual value was 3,00 collections.
[PASS] Expected TotalCollections [Gen1] to must be exactly 2,00 collections; actual value was 2,00 collections.
[PASS] Expected TotalCollections [Gen2] to must be exactly 1,00 collections; actual value was 1,00 collections.

------------ FINISHED Tests.GCCollection+Gen2Collection ----------

```

# The final results

    Gen 0 ticks:       36631
    Gen 0+1 ticks:     524
    Gen 0+1+2 ticks:   1358065

Yes, the difference between generation 2 and 1 is almost **2600 times!**

To be sure below are averages from 5 runs:

    Gen 0 ticks:       38364
    Gen 0+1 ticks:     424
    Gen 0+1+2 ticks:   1403400.6

So generation 1 is surprisingly fast, and generation 2 collection is relatively slow (remember those are ticks! Not milliseconds!). But case closed?

Not exactly.<br/>
Take a look at this test:

```csharp
[PerfBenchmark(Description = "Gen 2 collection with nothing", NumberOfIterations = 1, RunMode = RunMode.Iterations, TestMode = TestMode.Test)]
[GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen0, MustBe.ExactlyEqualTo, 3d)]
[GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen1, MustBe.ExactlyEqualTo, 2d)]
[GcTotalAssertion(GcMetric.TotalCollections, GcGeneration.Gen2, MustBe.ExactlyEqualTo, 1d)]
public void Gen2CollectionWithNothing()
{
    _list = null;

    var sw = Stopwatch.StartNew();

    RunGCAndCheck(0, sw);/* Run collect for gen 0 - collect everything.*/

    RunGCAndCheck(1, sw);/* Nothing should be here.*/

    RunGCAndCheck(2, sw);/* Nothing should be here.*/
}
```

It should collect everything in generation 0 collection, the rest should be close to 0, but here are the results:
    
    Gen 0 ticks:       32872
    Gen 0+1 ticks:     358
    Gen 0+1+2 ticks:   1297617

So yeah. Basically no difference from previous test. So this post should be named *"The cost of GC - a failed try"*. I don't know what to make of it. I have some ideas what to change and what to check to be more sure that those numbers are valid.

If anyone has any suggestions I've put this code in a [repo on github](https://github.com/maklipsa/CSharpPerfExperiments), any pull requests are welcomed.