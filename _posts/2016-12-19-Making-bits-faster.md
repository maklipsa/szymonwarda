---
layout: post
title: Making bits faster
description: "Bit operations are fast, but they can still be made faster"
modified: 2016-12-19
tags: [.NET, cookit, performance, similarity, bit operations]
series: "How I calculate 17 bilion similarities in cookit"
image:
  feature: data/2016-12-19-Making-bits-faster/logo.jpg
---

This post was inspired by a [discussion on Reddit](https://www.reddit.com/r/programming/comments/5i2x5r/using_bit_masks_for_highperformance_calculations/) that followed my [previous post](http://indexoutofrange.com/Using-bit-operations-for-performance-optimizations/)

In this post, I will cover a [suggestion](https://www.reddit.com/r/programming/comments/5i2x5r/using_bit_masks_for_highperformance_calculations/db5ujwc/) by [BelowAverageITGuy](https://www.reddit.com/user/BelowAverageITGuy) that cut down the total execution time by almost one hour.
<!--MORE-->

## Recap 

The last implementation of `GetNonZeroIndexes` looked like this:

```csharp
public IList<int> GetNonZeroIndexes()
{
    List<int> ret= new List<int>();
    for (var i = 0; i < _array.Length; i++)
    {
        if (_array[i] != 0L)// this one check saves me 64 ones
        {
            if (IsBitSet(_array[i], 0)) ret.Add(i * 64 + 0);
            if (IsBitSet(_array[i], 1)) ret.Add(i * 64 + 1);
            if (IsBitSet(_array[i], 2)) ret.Add(i * 64 + 2);
            if (IsBitSet(_array[i], 3)) ret.Add(i * 64 + 3);
            .
            .
            .
            //You get the idea
            .
            .
            .
            if (IsBitSet(_array[i], 61)) ret.Add(i * 64 + 61);
            if (IsBitSet(_array[i], 62)) ret.Add(i * 64 + 62);
            if (IsBitSet(_array[i], 63)) ret.Add(i * 64 + 63);
        }
    }
    return ret;
}
```

With `IsBitSet` looking like this:

```csharp
[MethodImpl(MethodImplOptions.AggressiveInlining)]
static bool IsBitSet(long b, int pos)
{
    return (b & (1L << pos)) != 0;
}
```

It is using bit operations that are very fast, so what can be done better?

{% include /newsletter.html %}

## Bit mask precalculation

His suggestion was to get rid of bit shifting and have the mask ready. This way I will get rid of `IsBitSet` and end up with `GetNonZeroIndexes` looking like this:  


```csharp
        public IList<int> GetNonZeroIndexes()
        {
            List<int> ret= new List<int>();
            for (var i = 0; i < _array.Length; i++)
            {
                var a = _array[i];
                if (a != 0UL)
                {
                    if ((a & 1UL) != 0UL) ret.Add(i * 64 + 0);
                    if ((a & 2UL) != 0UL) ret.Add(i * 64 + 1);
                    if ((a & 4UL) != 0UL) ret.Add(i * 64 + 2);
                    if ((a & 8UL) != 0UL) ret.Add(i * 64 + 3);
                     .
                    .
                    .
                    .
                    .
                    if ((a & 1152921504606846976UL) != 0UL) ret.Add(i * 64 + 60);
                    if ((a & 2305843009213693952UL) != 0UL) ret.Add(i * 64 + 61);
                    if ((a & 4611686018427387904UL) != 0UL) ret.Add(i * 64 + 62);
                    if ((a & 9223372036854775808UL) != 0UL) ret.Add(i * 64 + 63);
                }
            }
            return ret;
        }
```

## Excel

I generate this code in Excel and after generating all the if statemenent the program started to crash. i wonder if You can spot the error:

|---
| Power of 2 | Value |
|:-|--------------------:|-|
|49| 140 737 488 355 328 | &nbsp;
|50| 281 474 976 710 656 | &nbsp;
|51| 562 949 953 421 312 | &nbsp;
|52| 1 125 899 906 842 620 | &nbsp; 
|53| 2 251 799 813 685 250 | &nbsp;


See it?<br/>
I've hit Excel (and Google docs for that matter) precision and in the 52th power of 2, it was rounded in a strange way. So instead of getting `1 125 899 906 842 624` I've got `1 125 899 906 842 620` :| There goes two hours lost on debugging the applications.

## Results 

How did it impact performance? It allowed the sample execution time to go down to 308.22 seconds. For all recipes I  get:

```console    
(297 / 2199) * 182184 ~ 6,8 hours (starting from 34 hours)
```

This shaved off almost 1 hour(!) from the best time. It also shows that even things as fast as bit shifts can be made faster.


<style>
table{
    width:300px !important;
}
</style>