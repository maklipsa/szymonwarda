---
layout: post
title: Don't do it now! Part 4. Hangfire details - dashboard, retries and job cancellation 
description: "A deep dive into Hangfire retries and job cancellation"
modified: 2016-08-17
tags: [.NET, Hangfire, architecture, job scheduling]
series: "Don't do it now!"
image:
  feature: data/2016-08-22-Dont-do-it-now!-Part-4.Hangfire-details-dashboard,retries-and-job-cancellation/logo.png
---

This part will cover few small topics:

- dashboard
- retries 
- more technical part of the `Hangfire.BackgroundJob` class API
- job cancellation
<!--MORE-->

## Dashboard
Let's start with the administrative dashboard because it gives a good background for the rest of the post.
It greets us with more or less this view:
![dashboard Main](/data/2016-08-22-Dont-do-it-now!-Part-4.Hangfire-details-dashboard,retries-and-job-cancellation/dashboard_main.png)
This is the main view of what the server is doing, and how well (are the jobs failing)
The more interesting part is the next view:
![dashboard Main](/data/2016-08-22-Dont-do-it-now!-Part-4.Hangfire-details-dashboard,retries-and-job-cancellation/dashboard_jobs.png)
There's a bit more detail about jobs in all states. They are self explanatory, maybe except the awaiting, but I will cover this in the next post.
We can go as deep as the state of the specific job, which will look like this:
![dashboard Main](/data/2016-08-22-Dont-do-it-now!-Part-4.Hangfire-details-dashboard,retries-and-job-cancellation/dashboard_failedJob.png)

And this brings us to the main motives of this post:

- auto retries
- the ability to requeue a job
- the ability to delete a job
- job cancellation

{% include /newsletter.html %}

## Auto retry
This one is easy. Hangfire will auto retry every job that failed (timeouted or thrown an exception) configurable [amount of times](http://docs.hangfire.io/en/latest/background-processing/dealing-with-exceptions.html) (10 by default). Each retry is an equivalent to normal enqueuing, so it lands at the end of the queue.

## Manual requeue
This can be done in several ways:

- on the job page
- on the jobs page (allows requeuing multiple jobs).
- manually using `Requeue` from `Hangfire.BackgroundJob` :

```csharp
    static bool Requeue(string jobId);
    static bool Requeue(string jobId,string fromState);
```
Remember the unique job id returned by schedule methods from [previous post](/Don't-do-it-now!-Part-3.-Hangfire-details-jobs/)? This is one of the places where it becomes useful. The overload has an additional parameter, `fromState` which is a fail switch. Job will be deleted only if it is in this exact state.

## Delete a job
A similar story to requeuing. It can be done from the UI or with the API:

```csharp
    static bool Delete(string jobId);
    static bool Delete(string jobId, string fromState);
```

No surprises here. The API is very similar as `Requeue`.
This would seem to end the topic of `Delete`, but one very important question should pop into Your mind:

> Just how does Hangfire delete a job? 

This question becomes even more interesting when:

- we look at [IJobCancellationToken in the documentation](http://docs.hangfire.io/en/latest/background-methods/using-cancellation-tokens.html), which means cancellation is supported.
- we see that Hangfire is using [`System.Threading.CancellationToken`](https://msdn.microsoft.com/en-us/library/system.threading.cancellationtoken).
- we take into account that `Delate` may be called from a **different machine** than currently executing the job.

## Job cancellation

Cancellation can be triggered by two events (and both of the handle it differently):

**1. Server shut down** 

When `BackgroundJobServer`([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/Server/BackgroundProcessingServer.cs)), which is responsible for job execution, is being shut down, it stops processing new messages and triggers [`Cancel`](https://msdn.microsoft.com/en-us/library/dd321955(v=vs.110).aspx) on its [`CancellationTokenSource`](https://msdn.microsoft.com/en-us/library/system.threading.cancellationtokensource%28v=vs.110%29.aspx?f=255&MSPPError=-2147217396). This token is used by the `Worker`([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/Server/Worker.cs))  class to create the `ServerJobCancellationToken` ([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/ServerJobCancellationToken.cs)) instance that will be injected into the method if it has a parameter of type `IJobCancellationToken`. Calling `ThrowIfCancellationRequested` on it, checks the token and throws [`OperationCanceledException`](https://msdn.microsoft.com/en-us/library/system.operationcanceledexception(v=vs.110).aspx). This exception is recognised as finishing due to issued cancellation. This way the server can gently close currently processing jobs.

**2. Job deletetion (job cancellation)**

`Delete` method uses the `IBackgroundJobStateChanger` ([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/States/IBackgroundJobStateChanger.cs)), implemented by `BackgroundJobStateChanger`([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/States/BackgroundJobStateChanger.cs)), to change the state of the job to `Deleted` and write it to storage. On this its responsibility finishes.
	
The rest of the cancellation logic is done in `ThrowIfCancellationRequested` in `ServerJobCancellationToken`([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/ServerJobCancellationToken.cs))

 
```csharp
	public void ThrowIfCancellationRequested()
	{
	    _shutdownToken.ThrowIfCancellationRequested();
	
	    if (IsJobAborted())
	    {
	        throw new JobAbortedException();
	    }
	}
```

The first line is checking the `CancellationToken` mentioned in server shut down case. The second gets the job state from the database and checks if there were any state changes indicating whether it should be cancelled (like changing the state by calling `Delete`). If yes, `JobAbortedException`([github](https://github.com/HangfireIO/Hangfire/blob/master/src/Hangfire.Core/Server/JobAbortedException.cs)) exception is being thrown. This exception is handled in a very similar way as `OperationCanceledException` (from which it inherits) and also will be recognised as a indication of finishing due to issued cancellation.