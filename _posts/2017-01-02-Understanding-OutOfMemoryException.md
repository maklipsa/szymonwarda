---
layout: post
title: Understanding OutOfMemoryException
description: "An analysis why OutOfMemoryException happens. Additionally a riddle why it happened this time."
modified: 2016-12-22
tags: [.NET, cookit, performance, similarity, bit operations, Working set, Private Bytes, OutOfMemoryException, riddle]
series: "How I calculate 17 bilion similarities in cookit"
image:
  feature: data/2017-01-02-Understanding-OutOfMemoryException/logo.jpg
---

In my [ongoing series on calculating similarities](/tags/#similarity) one angle always seemed worth trying, and was pointed out many times on Reddit - use C++ and matrix manipulations. Similarity calculation fits very nicely into matrix representation, and there are algorithms targeting sparse matrix manipulation. So why did I delay it for so long? Because I had other angles I wanted to try and, from the looks of it required significant changes in the existing code base. But since [last optimizations didn't bring the time cuts I've expected](/Divide-and-conquer-bits-for-performance/), the time has come. Brace yourself.

<!--MORE-->

## Use matrixes

After some refactoring, I've managed to create a place where I could swap the existing implementation for the new one. 

> It took ~30 minutes of thinking, going back and fourth, but in the end, I've maneged to fit in without adding changes to the external code only for this implementation. So think, think, think and then code. Not the other way around. It is faster that way.

The function signature is this:

```csharp
public static Dictionary<int, List<RecipeSimilarityLight>> calculateSimilarityMapForAll(
        Dictionary<int, IngredientWeightsVector> recipeIngredientVector
        , ILogger logger)
        {
```

where:

- `Dictionary<int, IngredientWeightsVector> vectorMap` is a dictionary where the key is `RecipeId` and `IngredientWeightsVector` is a `IDictionary` containing the owned ingredients and weights. 

I first wanted to try the most brute force approach possible - using `float[][]` without any fancy algorithms. Just to have a reference point. So here it is: 

```csharp
public static Dictionary<int, List<RecipeSimilarityLight>> calculateSimilarityMapForAll(
    Dictionary<int, IngredientWeightsVector> vectorMap
    , NLog.Logger logger)
{
    //similarity calculations
    var matrix = CreateRecipeMatrix(vectorMap);
    var transposeMatrix = Transpose(matrix);
    var multiplyed = Multiply(matrix,transposeMatrix);
    var vectorsLength = ComputeVectorsLength(vectorMap);
    var resultMatrix = Normalize(matrix, vectorsLength);

    //finding the most similar recipes
    var dict = initSimilarityMap(allRecipes);
    int index = 0;
    for (int i = 0; i < resultMatrix.Length; i++)
    {
        if (index % 500 == 0)
            logger.Info("Calculated: " + index + " from: " + allRecipes.Count);

        var recipeId = allRecipes[i];
        for (int j = 0; j < resultMatrix[i].Length; j++)
        {
            var secondRecipeId = allRecipes[j];
            var similarity = resultMatrix[i][j];
            addSimilarityIfGoodEnough(dict[recipeId], recipeId, secondRecipeId, similarity);
        }
    }
    return
        dict
            .ToDictionary(a => a.Key, a => a.Value.ToList());
}

```

After clicking run I saw this:

```console
Unhandled Exception: OutOfMemoryException.
``` 
and soon after, this:

![Your computer is low on memory.png](/data/2017-01-02-Understanding-OutOfMemoryException/your-computer-is-low-on-memory.png)

So without terminating the application I fired up Task Manager and saw this:

![](/data/2017-01-02-Understanding-OutOfMemoryException/TaskManager.png)

So what is going on here? I have 16 Gigs of RAM and I get OutOfMemoryException from a process holding less than one?

Since there are many ways to look at one problem I fired up something more advanced - [Process Explorer](https://technet.microsoft.com/en-us/sysinternals/processexplorer.aspx) from Microsoft. 

> Process Explorer is a part of [SysInternals Suite](https://technet.microsoft.com/en-us/sysinternals/bb842062.aspx) and it is a MUST HAVE for anyone using Windows environment. It requires no installation, just copy and paste.

Process Explorer showed the same and [something completely different](https://www.youtube.com/watch?v=FGK8IC-bGnU){:target="_blank"}:

![](/data/2017-01-02-Understanding-OutOfMemoryException/ProcessExplorer.png)

One number is the same (there is a slight difference due to my computer crashing because of low memory), but the other number is a bit, to say it politely, different. And it is huge - **35 gigabytes**. So what are those two categories and why is Task Manager showing one, and not the other? 

To fully understand why did I get `OutOfMemoryException` while still having much RAM memory free we will have to understand, at least a bit, memory allocation in Windows and .NET Framework.

{% include /newsletter.html %}

## Windows, memory allocation and .NET Framework

So how I ended up with ~800MB `Working Set`, ~45 times larger `Private Byes` an `OutOfMemoryException` and `Your system is low on memory` message from Windows? This has to do with the way .NET Framework behaves.

Windows has a few used memory measurement, but I will concentrate on two of them:

- Private Bytes also called the Private Set
- Working Set

What is the difference?

Before I continue one note:
There is a lot more to Windows and .NET memory management. I've taken only the parts needed for this problem. Go and read the linked articles for more in depth knowledge.

### Working Set

A simple explanation:

> Working set is the **RAM** memory that the process is currently using. 
> Touching memory fragment for the first time moves it from *Private Bytes* to *Working Set*[[source](https://blogs.msdn.microsoft.com/tims/2010/10/29/pdc10-mysteries-of-windows-memory-management-revealed-part-two/)]  

Precise one:
This is the memory that the process can is currently using. Here are all variables and mapped files.

### Private Bytes

To put it simple:
 
> **Private Bytes** is the memory that the process **might need**.  

A more precise:
This is the amount of memory that the OS thinks the process will need in the near future. To be even more precise it is the *amount of space that has been allocated in the swap file to hold the contents of the private memory in the event that it is swapped out* [[source](https://blogs.msdn.microsoft.com/ricom/2005/08/01/private-bytes-performance-counter-beware/)]. As mentioned by the cited article this value may, and very often is, overestimated by the OS.

So why is the OS thinking I will need 35 gigabytes of memory? It must be the .NET Framework.

### .NET Framework memory allocation

When running managed code .NET Framework is taking care of memory allocation and collection. It is allocating memory in bigger chunks from the OS, so that when creating a variable, so allocating memory for it, we are not communicating with the underlying system, but only with the runtime. Why .NET is doing it? For several reasons:

- To keep track of the allocated objects so it can garbage collect them.
- For performance. Allocating a 20 MB chunk with one call will faster than doing it with 2000 100KB calls.
- Memory fragmentation.

The last one needs a it more clarification:
This is the situation when where is no continuous block of free memory of requested size, but the sum of free memory is bigger than requested. Because one ASCI art says more than 1000 words here it is:

```console
Our memory:
|oo_o_ooo__o_o_o|
where:
- o - allocated
- _ - free
``` 
In this situation, although we have 6 slots of free memory we can't allocate a 3 slot object. 
How is .NET different from the OS in this subject? .NET can change the physical address of the object in the [compaction phase of the garbage collection](https://msdn.microsoft.com/en-us/library/ee787088(v=vs.110).aspx) as long as it is not pinned using [`fixed`](https://msdn.microsoft.com/en-us/library/f58wzh21.aspx).

So .NET Framework is over allocating, and then Windows is also over allocating and this ends up in the system running out of memory and crashing my application? This means that the framework AND the operating system is broken?

It is best not to assume that step back, have a break and look at the code once again in few minutes.

## The mystery

I finally figured it out and it was so obvious that I felt stupid. Can You guess why did I run out of memory? To make it easier:

- the framework is not broken
- Windows is not broken (at least in this case) 
- read the [first](/How_I_calculate_similarities_in_cookit/) and the [second](/How-to-calculate-17-billion-similarities/) post.

There are no awards, but I will try to highlight those who get it. 