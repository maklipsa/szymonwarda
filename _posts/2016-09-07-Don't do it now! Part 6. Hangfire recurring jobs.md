---
layout: post
title: Don't do it now! Part 6. Hangfire details - recurring jobs and cron expressions
description: "A look into cron expressions and how Hangfire handles recurring jobs"
modified: 2016-09-07
tags: [.NET, Hangfire, architecture, cron]
series: "Don't do it now!"
image:
  feature: data/2016-09-07-Dont-do-it-now!Part-6.recurring_jobs_and_cron_expressions/logo.jpg
---

Parts [3](/Don't-do-it-now!-Part-3.-Hangfire-details-jobs/), [4](/Don't-do-it-now!-Part-4.-Hangfire-details-dashboard,-retries-and-job-cancellation/), and [5](/Don't-do-it-now!-Part-5.-Hangfire-job-continuation,-ContinueWith/) covered the `BackgroundJob` class responsible for enqueuing single jobs (fire and forget). This post will cover `RecurringJob` class exposing API for recurring jobs (as the name suggests).

## Recurring job
Before we go into the API, let's take a look what is a recurring job in Hangfire.
Recurring job is a timer that enqueues a job at specific time intervals defined with a cron expression. What is important is, that it does not execute the job. Only enqueues an ordinary Hangfire job. This implementation is very elegant, but it also means that if the queue is full the job will have to wait for its turn. So there is no guarantee about the time it will actually execute.
<!--MORE-->

## Cron expressions
I've mentioned cron expression few times, but what exactly are they? Cron expressions are a way to express time occurrence, like *"every Monday at 8"*, or *"second Thursday of the month at 5:30"*. How do they look? A few examples:

- **every Monday at 8** can be expressed by `0 0 8 ? * MON *` 
- **second Thursday of the month at 5:30** can be expressed by `0 30 5 ? 1/1 THU#2 *`
- **second Thursday of *every third month* at 5** can be expressed by `0 30 5 ? 1/3 THU#2 *`

Just looking at the examples above a pattern emerges:

`[seconds] [minutes] [hours] [day of month] [month] [day of week] [year]`

Most of the fields accept special characters:

- `*` - all values
- `?` - no specific value. So what is the difference between `*` and `?` ? The first one selects all values and the second one says "I don't care about it". Like with the `0 0 8 ? * MON *` example. We put `?` into `day of month` field because which day of the month it will be is not important.
- `-` - for ranges. For example: `MON-FRI` for selecting *workweek days*.
- `,` - naming multiple values. For example: `MON,FRI` for selecting *Monday and Friday* **only**
- `/` - for adding intervals. It is used like `x/y` which means: "start at x and do it every y times". For example: `0/10` in seconds field will result in values: 0,10,20,30,40,50. One thing to look out for is that cron uses human notation, so with days, months etc. we start counting from 1, not 0, like in example 2 and 3 above.
- `L` - last. It is allowed in two fields: `day of month` and `day of week`. This comes in handy when talking about the last day of February and not having to worry about leap years. It gets even better, and more confusing, when used for example like this: `L-1` in the `day of month` field. Why is it powerful and confusing? Because it doesn't mean *"the last day and day before the last day of the month"* ( `-` is for expressing ranges), but it means *day before the last day of the month*. So strange, but powerful since it gives the possibility to enumerate on days starting from the end of the month/week.          
- `W` - **nearest** weekday. How is it different from naming `MON-FRI`? It returns the **nearest** working day from a given date. So:
    - a cron: `0 0 12 4W 9 ? *` in the year 2016 will return the *5 of September 2016 12:00* since 4 of September 2016 is Sunday, so Monday is the nearest.
    - a cron: `0 0 12 3W 9 ? *` in the year 2016 will return the *2 of September 2016 12:00* since 3 of September 2016 is Saturday, so Friday is the nearest.
    - a cron: `0 0 12 1W 10 ? *` in the year 2016 will return the *3 of October 2016 12:00* despite the fact that it is Saturday. Why? Because it returns the nearest workday **in a given month**
- `#` - the nth value. Think of it as `/` but without the iteration. Only allowed in `day of week` field  For example:
    - a cron `6#2` used in `day of week` means *second Friday of the week*. Why Friday? Because in this case days of week are numbered from 0 (Saturday)

If this looks complicated there is a [cron expression builder online](http://www.cronmaker.com/) and Hangfire has a helper class `Hangfire.Cron`. Inside Hangfire uses NCrontab ([nuget](https://www.nuget.org/packages/ncrontab/), [github](https://github.com/atifaziz/NCrontab)).

Ok, lets get back to Hangfire and `RecurringJob` class. It has three functions (excluding the overrides):

{% include /newsletter.html %}

## AddOrUpdate
As the name suggests it enables to create or update a recurring job. Without further ado let's look at the overrides, because there are a few of them:

```csharp
    
    static void AddOrUpdate(Expression<Action> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate(Expression<Action> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    
    static void AddOrUpdate<T>(Expression<Action<T>> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate<T>(Expression<Action<T>> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    
    static void AddOrUpdate(string recurringJobId, Expression<Action> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate(string recurringJobId, Expression<Action> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    
    static void AddOrUpdate<T>(string recurringJobId, Expression<Action<T>> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");

    static void AddOrUpdate(string recurringJobId, Expression<Func<Task>> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate(string recurringJobId, Expression<Func<Task>> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");

    static void AddOrUpdate<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, Func<string> cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
    static void AddOrUpdate<T>(string recurringJobId, Expression<Func<T, Task>> methodCall, string cronExpression, TimeZoneInfo timeZone = null, string queue = "default");
```

The total count is twelve functions, so what exactly differentiates then?

- generic vs. nongeneric
- requiring or not job Id. When using the overload without id, one will be generated as a concatenation of object type name and method called. 

> From my personal experience specifying the id is a better practice. It makes code refactoring easier because we don't have to worry that we will lose the ability to alter the job because of refactored name.
     
- cron expression passed as a string or as a function returning a string (string vs. `Func<string>`). I personally don't see the use case for a function returning a string cron expression, but maybe it will be useful to someone.  
- enabling scheduling synchronous or asynchronous jobs (`Expression<Action>` vs. `Expression<Func<Task>>` or `Expression<Action<T>>` vs. `Expression<Func<T,Task>>` for generic overrides)

They all have:

- `TimeZoneInfo` -  because knowing the timezone is important when talking about hours
- `string queue` - as the name suggests jobs can be scheduled onto different queues, but I will leave it for now since it will be covered in future posts.

## Trigger
With function signature looking like:

```csharp
    static void Trigger(string recurringJobId);
```
There is no doubt what it does - triggers the job. This of curse does not influence next scheduled triggering since they are scheduled in absolute time, not relative from the last execution.  

## RemoveIfExists

``` csharp
    static void RemoveIfExists(string recurringJobId);
```
Not much to say. It removes a scheduled job. Again, the job has to have an id. And it will remove only the trigger. Any enqueued jobs will execute.


## Corner cases

### What happens if I schedule the job to start in the past?
The job will be triggered when the next interval happens. Past jobs won't be queued.

### What happens if during the time the job should be triggered there was no processing server?
It depends:

- if the job was enqueued at least once and during downtime it should be triggered, then it will be enqueued.
- if there was never any triggering, it will be triggered next time in the future according to cron expression.
   
This logic is in `TryScheduleJob` function in `RecurringJobScheduler`.

### What is the minimal precision for triggering a job?
One minute. It is achieved by a busy with a one-second sleep wait in `EveryMinuteThrottler`.