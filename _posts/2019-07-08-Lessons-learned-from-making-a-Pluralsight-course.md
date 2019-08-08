---
layout: post
title: Lessons learned from making a video course for Pluralsight  
description: "Recording a video course isn't easy. Below are a few things that would make recording my first course easier."
modified: 2019-07-08
tags: [Pluralsight, non-technical]
image:
  feature: data/2019-07-08-Lessons-learned-from-making-a-video-course-for-Pluralsight/logo.jpg
---

So, Yes. I hit a pause button on writing because many things were happening, and as it turns out, you can only squeeze 24 hours in one day. Who knew? 
However (hopefully) my blog will come back to life. 
One of the things that kept me busy during this time was realizing one of my goals: 


<div class="center">
    <div class="button" > Make a video course for Pluralsight. </div>
</div>


And I [made it](https://app.pluralsight.com/library/courses/microsoft-tpl-dataflow/table-of-contents):
<!--MORE-->

[![](/data/2019-07-08-Lessons-learned-from-making-a-video-course-for-Pluralsight/pluralsight.jpg)](https://app.pluralsight.com/library/courses/microsoft-tpl-dataflow/table-of-contents)

Now that it is done, and I had a few months to reflect, a few lessons for those thinking about doing **any video course**.

# Preface 

## Choosing the course

Before we talk about what I learned, a few words about the course itself. First, how did I choose the topic. I had a few criteria:

- I wanted to make a course about something that I feel is very underrated mostly because of lack of awareness in the development community.
- I didn't want to do **yet another** course about what is driving the hype train currently.
- I wanted to make a course about something that I know but could use the course to structure and deepen my knowledge. As the saying goes: *if You want to learn something, teach it to someone*.

A few topics fitted those criteria:

- graph databases
- TPL Dataflow
- general concepts of data modeling

After much thinking and talking with people from Pluralsight, the decision was made to do a course about TPL Dataflow. It fitted the criteria perfectly:

- Not too many devs know TPL Dataflow
- I used it a lot when [optimizing cookit](/How_I_calculate_similarities_in_cookit/) and [calculating 17 billion similarities](/How-to-calculate-17-billion-similarities/)
- It's a perfect tool for some use-cases. I wanted to have a deeper understanding of how it works.

## What is TPL Dataflow?

TPL Dataflow is one of those gems that Microsoft sometimes develops and doesn't put enough effort to inform the public (similar cases: Reactive Extensions, Orleans).

Apart from the above it's a [nuget package](https://www.nuget.org/packages/System.Threading.Tasks.Dataflow/) (available for .net framework and .net Core ) that implements the [Dataflow Programming Model](https://en.wikipedia.org/wiki/Dataflow_programming). Dataflow Programming Model might sound ancient and abstract but just looking at the current implementations: [TensorFlow](https://www.tensorflow.org/), [Apache Beam](https://beam.apache.org/) and [Apache Flink](https://flink.apache.org/) gives the domain where it is appliable: **highly parallel, throughput orientated workloads**.

In a nutshell, the main concepts are:

- business logic should not mix with execution logic.
- code is encapsulated in blocks that can be linked to each other.
- optimize for the throughput, not latency (can be tweaked).
- optimize the performance of the whole workflow, not a single step.
- data consistency over availability (this also can be changed).

Since this post isn't about TPL Dataflow or the Dataflow Programming Model I will leave it here. If You want to know more [see me the course I guess](https://app.pluralsight.com/library/courses/microsoft-tpl-dataflow/table-of-contents).

# The lessons

I won't advise on choosing the topic, but let's assume You have one. What next?

## 0. Find the key

You have the title, but can't get to actually making the thing?
You might say that this is normal because starting is hard. Which part of starting is hard? Why is it hard?

For me, and reading the lessons learned of other people that made a video course, the biggest stopper for starting was knowing **how do I structure the course**? Phrasing it differently: **how to tell the story**?

There are a few approaches:

### 0.1 The builder

During the course, we build something (in 95% of the cases a website) using some framework and learn along the way. The most significant advantage of this theme is that it is *very engaging*. Developers want to build stuff. It also gives a purpose and some sense of accomplishment. On the downside, You will be building a yet another typical example (blog, forum, shop, etc.) because choosing an overcomplicated domain will waste to much time on explaining it.
Additionally, the building order isn't the learning order, so You will end up with digressions or using some feature that will be explained later on. Lastly, and for me, it was the biggest drawback, some features of the framework don't make sense in what You are building. So you either leave them out (not a good idea) or cram them in somehow with little sense.

### 0.2 Feature centric 

This approach concentrates on the features of the framework/topic at hand without actually building anything bigger than a few lines of code. The most significant advantage of this is that we can start from the fundamental parts of the framework and then progress to the more intricate features building on the knowledge gained earlier. This gives a natural, easy to understand progress path. 
The benefit of not building anything big is that the code samples demonstrating the feature can be more narrowed down to showcase the problem, making them easier to understand.
On the downside, it is less rewarding for the viewer, we have less real-life usages, and no fully working solution at the end.

{% include /newsletter.html %}

### 0.3 Problem solver

An interesting approach mitigating the problems of the **feature centric approach**  is to demonstrate the features on tiny problems that don't work at first. From my experience in mentoring people, [doing workshops](/workshops/), and based on Pluralsight review feedback, it is more engaging than just showing things that work out of the box. 
Troubleshooting issues also make it easier to show the underlying principles of the framework.

### 0.4 Mix it! And my approach

Those themes are not exclusive. You can switch between them during the course and use multiple at the same time (especially the problem solver).<br/>
I went with the feature-centric approach with a lot of problem-solving. This allowed me to do a deep dive into how Dataflow works and show how the basic principles that we discovered in the early clips apply to the advanced features. Such combination allowed me to fulfill one of my goals - **teach how it works, not only how to use it**.

Choosing the feature-centric approach doesn't mean that we have to say goodbye to the problem solver. One way we can use it is to extend the same code sample in progressive exercises. We start with something simple, then add problems and features showing how to build more substantial systems. That proved to be a significant time-saver for me since it eliminated the need to explain the starting point with each clip.

## 1. Plan your work

You have the vision soo start coding? No.
Don't just start doing the course. Planning is important. People will watch it to learn something. Don't waste their time with chaotic mumbling, or get a per review saying rethink Your life.
If You don't care about viewers time (that is strange on its own. Please rethink it. ) You should care about Your time. 
The same chart we know from software development:

![](/data/2019-07-08-Lessons-learned-from-making-a-video-course-for-Pluralsight/bugfixingcost.jpg)
source: https://deepsource.io/blog/exponential-cost-of-fixing-bugs/

Applies to courses also. Redoing a recorded video because You forgot to say something essential that is needed one hour later is frustrating and very time-consuming.

## 2. Write a checklist

Write a list of things that You want to talk about. Don't concentrate on order. There will be time for this later. It might be some high-level stuff or really tiny bits that are interesting. Don't focus on this. Just dump everything into a text file or a piece of paper.<br/> 
Once You have it go through it and check if nothing is missing. Give yourself time since doing it properly now will save a lot of time in the future.

## 3. Write an index first

You have the checklist. Now:

### 3.1 Group it.

Assign the small bits to some larger topics that are best suited for explaining them. If there is no such topic just create one. Now you should have topics of more or less the same size. Next step is to:

### 3.2 Add order

Now we need some order in our list. Try to put the main topics in such a way that the viewer will build upon the gained knowledge. <br/>
This might sound simple, but there is a problem. We can't bore someone with the basics for the first 45 minutes because noone will have enough paitience to wait for the usefull stuff. The first question that viewers will ask is: is this useful for me? If no, they will stop watching.<br/>
The best approaches I found was to show how to use the framework while demonstraiting the underlying principles in the meantime.[Part 3 of my course](https://app.pluralsight.com/player?course=microsoft-tpl-dataflow&author=szymon-warda&name=bea807e8-2958-499e-9a35-2031aa12d8eb&clip=0&mode=live) uses this approach. In each clip, I go through one building block of Dataflow and also show the basics as input and output queues, how to control concurrency, and how messages are delivered. Talking about them separately and without real-life examples would make the basics boring. 
To be frank, this is the part of the course I am most happy with (except for non-technical issues, but more about them later). 

## 4. Write a script and code

I know that for some people having the list above is enough. They just start live coding and recording. For me, and probably for anyone doing it for the first time, it wasn't the case.
I tried it and the amount of time that went into editing the recorded video and audio to make it watchable was too big. It turns out editing text is easier than editing video. Again who knew? ;)
For the n-th course, I will probably be able to do that. But for the first one, I decided to write an exact script that I would record.
Another great idea was to write the code samples with the script.<br/>
For me, this approach was a blessing. Thanks to it I:

- discovered topics that I needed to explain before for some clips.
- noticed that in some cases, I need to rearrange the clips.
- saw opportunities where I could reuse code from previous exercises in the next ones making the course more connected.
- removed the writer's block. For me, writing code is more natural than writing a script. Starting from the code and writing the script along the way was just more comfortable.
- verified my own knowledge. To be honest, there were a few cases, especially with some inner working details, where I thought Dataflow would behave differently.  Having code that proved and verified my assumptions eliminated errors.
- was able to reuse the audio from different takes to make the final cut.

Writing the script was a significant time investment, but looking back, I would make it once again.

## 5. Just do it

Having said so much positive stuff about the benefits of writing a script don't over do it. I made the mistake of spending to much time reading and fixing it.<br/> 
Write the script, read and fix it once, and move on to recording. Record the audio and video and then fix the script. A few reasons why:

- Trust me. You will find way more bugs and issues in the text, and code samples, by watching the recording than by reading the script and looking at the code samples.
- Long, complex sentences are acceptable when written, but reading them is a nightmare. Listening also isn't easy. I had to fix a lot of such sentences.
- Doing the whole pipeline now will give You an overall view of what awaits. Every medium has its own does and don'ts. Knowing them soon is very beneficial.
- You will gain some estimations on how long each clip is. They shouldn't be too long or too short. About 7 minutes is perfect.
- Start getting used to Your own voice. Most people don't like how they sound on a recording. This is normal. People around You don't mind, and You will spend a few hours listening to Yourself. Have it over with.
- The first take will be bad. It will go into the trash can. Don't spend to much time on it. **Do it, learn from it and move on.**

## 6. Do audio and video separately

Again, more seasoned trainers do it differently. For me doing the audio when codding was too much to do at once. It leads to many "yyyyyy" and code errors. Doing it separately was easier for me, and I didn't have to worry about recording the keystrokes.

## 7. Don't strive for perfection

You will see more errors, issues, and things to improve in the video than any other viewer. But keep in mind that people watch it for knowledge, not artistic perfection. If the knowledge is there and it is well served You will do just fine. 

# FAQ 

## What was the hardest?

Finding a concept of how I wanted the video to be structured and recording audio. 

## How much time did it take?

I didn't count exactly but way too much because I had to learn so many things. At the end, doing one clip (audio + codding +  slides + cutting + export) took between 1-4 hours.
In the beginning, it was closer to 7 hours (mostly because multiple audio takes).

## Would you do it again?

Yes. I learned a ton. Not only how to make video courses, but also about Dataflow and I have a ton of killer exercises for [my workshops about Application Architecture](/workshops/application-architecture/)

## Would would you do differently?

I would redo the recording. But after recording it once, I would probably want to redo it once again...

## Are you happy with how it turned out?

No. Anyone who knows me knows that I always see things to improve. The same with the course. I would rate myself with 3/5, but [viewers on Pluralsight](https://app.pluralsight.com/library/courses/microsoft-tpl-dataflow/table-of-contents) give it 4/5 soo I won't argue.

## What would I change? 

How slow I talk. It should be faster. In person, I am a fast talker, and I was concerned that I would be in hard to understand for non-native speakers. I overdid it. But this is what the video playback speed regulation is for. I guess.

# Links, further reading etc:

- [Dataflow nuget package](https://www.nuget.org/packages/System.Threading.Tasks.Dataflow/) 
- [Dataflow documentation](https://docs.microsoft.com/en-us/dotnet/standard/parallel-programming/dataflow-task-parallel-library)
- [My Pluralsight course](https://app.pluralsight.com/library/courses/microsoft-tpl-dataflow/table-of-contents)
- [My workshops on Application Architecture where I show more non standard architectures](/workshops/application-architecture/)