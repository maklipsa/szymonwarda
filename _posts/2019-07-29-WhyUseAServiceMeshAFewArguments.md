---
layout: post
title: Why use a service mesh? A few arguments
description: "Kubernetes is THE topic of discussions in IT now. I would argue that it is only an intermediate step."
modified: 2019-07-30
tags: [kubernetes, k8s, service mesh, architecture]
image:
  feature: data/2019-07-29-Why-use-a-service-mesh-a-few-arguments/logo.jpg
---

I will be back to the [series about data modeling in noSQL databases](/Modeling-version-and-temporary-state-in-noSQL-databases/), but for now, I want to note down a few arguments that are still hot after an interesting discussion with a friend.
The talk boiled down to a simple question: 

<div class="center">
    <div class="button" >Should I use a service mesh or use a bare bones Kubernetes?</div>
</div>

<!--MORE-->

I know how strange the combination of bare-bones and Kubernetes sounds, but this is the world we are living in :).

I'm standing firmly on the position that service mesh is the only way to go. Here is why:

## A service mesh means less code

A correctly implemented synchronous call should have the following policies/rules around it:

- getting a JWT token for authentication
- timeout for the service we are calling
- retry policy with exponential backoff and jitter
- circuit breaker (a distributed if possible)
- caching
- fallback policy on what happens if the service is down
- a timeout to wrap the whole thing since it isn't that simple any more.

Depending on what framework, or language this will be ~200-400 lines of code. For one HTTP/[gRPC ](https://grpc.io/)call!
I know they can be applied globally using things like [HttpClientFactory](https://docs.microsoft.com/en-US/dotnet/standard/microservices-architecture/implement-resilient-applications/use-httpclientfactory-to-implement-resilient-http-requests) in .net, but they still need to be defined somewhere.
The argument that "we can define them once and reuse" is false. Those policies will/should differ depending on the business use case. Reuse will be possible, but not to a full extent.

# Developers don't ...

## Developers don't care

This title is a read-bate, but let me explain. Developers are not the ones who will get the call when the system crashes. 
They should be, but in most cases, the on-call person will be someone with "DevOps" in the job title. 
This creates a week incentive for implementing those rules **properly**. Most developers have their backlogs full of business features that will take them more than a year to implement. They won't spend enough time on this. 
And even if they would:

## Developers don't understand

Let's take a developer that will want to do it properly. To implement all the policies correctly, he, or she would have to understand all the ways a system might fail.
This knowledge can be gained from:

- Watching systems fail daily.
- Doing post mortem and root cause analysis.
- Having access to systems failing where people notice - the production environment.
Those are not the tasks of a developer, but an SRE (**S**ervice **R**eliability **E**ngineer). 

## Developers don't have the numbers
 
Let's imagine a person who wants to do it properly, and will spend a lot of time understanding how a system might fail. They would be still missing some crucial information. **The numbers.**
Almost every policy has some number attached to it:


| Policy | Number | Sources |
|:------|:---------|:---------|
| Timeout of the service we are calling | Timeout value | SLA agreement verified using System monitoring |
| Retry | Number of retries <br/> Backoff time <br/> Jitter value | System monitoring |
| Caching | Caching time | HTTP headers <br/> System montoring|
| Circuit breaker | Open state time | System monitoring |

<style>
    table {
      border-collapse: collapse;
    }
    table, th, td {
      border: 1px solid black;
    }
    th{
      font-weight: bold;
    }
</style>

Even if the developer acquires those values, they might change over time. What then? Should we redeploy the code to change the timeout value? It doesn't sound reasonable. 
The alternative is to have them in a config file, leading do a large and unmaintainable file.

{% include /newsletter.html %}

# The circuit breaker

The circuit breaker policy is the one that gains the most when done in the layer of a service mesh. For two reasons:

## Distributed circuit breaker

Having a circuit breaker is fine. But it is only the beginning of what it can and should do to protect our system from cascading failure.

A standard circuit breaker works in the scope of a single application, not the whole system. It looks at requests going out of the service and monitors the number of errors. If the percentage of errors crosses a particular value, communication to that server is cut for some time. We do it not to escalate failure to other services. When looking from a single service point of view, it is the right solution.

When looking from the point of view of the whole system, the problem is still unresolved. Because each service has to open it's breaker independently, services will hammer the under stress service.
The more reasonable way to do it is to use a distributed circuit breaker. A distributed circuit breaker broadcasts the information about opening and closing a breaker to other services. If a breaker in one service opens, others will be notified about this via the broadcast, and also open. 
This way, we remove a faulty service from the whole system almost at once.

Implementing a distributed circuit breaker in the application code is not a trivial task and will require the use of some centralized coordinator. 

When switching our mindset to a service mesh where we are proxying all incoming requests, the solution becomes very simple. We can break on the proxy — a much simpler solution.

## Overload circuit breaker

The circuit breaker pattern is protecting the caller from calling a faulty service. That is great. We fail faster and protect from requests piling in on our input while retrying or waiting on the defected service.
Now let's think about the electric circuit breaker. It works differently. The real one protects from a too high current **entering the system**. In system architecture terms: **from too many requests entering the application**. 
Adding requests to a system under load will only make it worse. With the exception to this:

<div style="text-align:center"><img src="/data/2019-07-29-Why-use-a-service-mesh-a-few-arguments/clicking.jpg" /></div>

It is better to fail them earlier and have a chance for the system healing itself. 
An overload circuit breaker protects from failure happening, not from the consequences of failure. Such a circuit breaker is hard to implement on the application layer, but very simple when using a service mesh.

# Get rid of documentation

At least some parts of it. A service mesh can easily give us the **actual** topology of the system. No more looking at diagrams and asking ourselves: 

<div class="center">
    <div class="button" >How outdated is it?</div>
</div>


Open Zipkin, Jaeger or Application Insights and see in real-time what service is used in which business process. Easy and, more importantly, accurate.
Some might argue that we can have this without a service mesh. Yes, we can. But it is easier to deploy and maintain it with a service mesh.

# Monitoring, tracing and centralized logging

Except for reporting business metrics, the application should not care what type of centralized logging system is used.
Why should we add a wrapper for measuring execution time to every call? 
We will end up with something like this :

```csharp
Timer t = Timer.Start();

_http.Get("http://google.com");

t.Stop()
_metrics.ReportTime("googlecall",t.ElapsedMilliseconds);

```

Application code isn't the right place to do it. It can, and should be implemented globally. This way, we will be able to:

- guarantee a standard for the naming scheme.
- be sure that all requests are logged.
- have all applications log to the same system.
- have logging independent from application framework and language.
- minimize the infrastructure boilerplate that is needed before a team can start delivering value.

# Reducing complexity

Granted, we can't remove complexity. We can only move it to a different place in the system. But moving technical services such as service discovery and API gateways from application code to infrastructure sounds OK to me. They shouldn't have any business code in them anyways.

# Security

Kubernetes, Docker, VPN, and sub-networks give us the possibility to narrow down the list of who can talk to who. A service mesh is going a step forward by monitoring who **is** talking and what type o traffic is it.
What makes it even better is that previously our monitoring would look at packets of TCP/IP or UDP traffic. In a service mesh, we are looking at HTTP traffic. This opens a lot of possibilities and makes some checks simpler.

# It just works

How important are the decisions below?:

- Eureka or Consul? 
- Jaeger or Zipkin?
- Grafana with InfluxDB or Graphite?

Doesn't the decision boil down to the question: **What works with what we already have?**
Most service meshes are an opinionated set of tools that work together. That is a good thing. I can live with a bit less system integration code in my backlog. Can You?

# What will be the difference in the end?

Going back to the talk that sparked the need for writing this article. The more we discussed, the more I got closer to the essential point:

<div class="center">
    <div class="button" >
Let's asume that you didn't use a service mesh.<br/> Then you add all the necessary infrastructure for a distributed system.<br/> <b>How different will it be from a service mesh?</b> 
    </div>
</div>

We won't have a lightweight reverse proxy deployed with every service (probably). But is this such a high overhead versus all the things that a service mesh makes easier?

# No flaws?

On the contrary! Service meshes offer even more ways to shoot ourselves in the feet, hands, the head, etc. Like with every technology we will have to spend time to learn it's pitfalls and how to avoid them. But this is a topic for a different conversation.
