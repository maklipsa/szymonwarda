---
layout: post
title: The missing Azure Functions documentation  
description: "Azure Functions documentation is a mess. It is even worst in blogposts. The reason for it is that there is no single Azure Functions offering. There are three."
modified: 2018-01-01
series: "Azure Functions"
tags: [azure, azure functons, F#, .NET, compilation]
image:
  feature: data/2018-01-01-The-missing-Azure-Functions-documentation/logo.jpg
---

Trying to understand how to run code in Azure Functions is not an easy task since this product has evolved on its own and thanks to the rise of .NET Core. This post will give You a history background necessary to understand the documentation and, most of all, all the blog posts talking about Azure Functions.  

<!--MORE-->

### v1.0 - script files 

The initial way to run code in Azure Function was to write a script file in Azure Functions portal editor. Yes, You read correctly - **in the portal editor**. Later on, deployment support was added, so we could deploy the script files (`fsx` and `csx`). 
It works good, but has some drawbacks:

- the compilation is done when the function is called for the first time (or called after an extended inactivity when Azure decided to kill the process)
- IntelliSense support is quite clumsy
- there is no compilation during development. When working on the code locally compiling the project did nothing since script files are not taken into account when compiling. This means that we are losing a lot of the benefits of a compiled language.  

{% include /newsletter.html %}

### v1.1 - compiled functions

Microsoft addressed most problems with script files with the introduction of compiled functions. This was not a change to how they worked since Azure Functions are hosted in WebJobs, so as IIS application. Compilation can be done two ways:

- **by deploying project code**. When we deploy a project (csproj/fsproj/sln) Azure Functions machine will trigger compilation on the hosted machine, deploy the result to `wwwroot` as `Default Website` and run discovery looking for functions declaration (this is done by a config file or special attributes).
- **by deploying compiled code**. This does not mean that we have to store binaries in the repository (although it would work). This means that we can treat Azure Functions as an IIS Website and use the good (?) old Web Deploy that we have been using since ASP.NET (btw. VSTS has an excellent configuration for Azure Functions deployment)

Why should we bother with option two since Azure can handle it? Option one (deploying just code) has some drawbacks:

- compilation is limited to .NET 4.6.1 (this is the version installed on the Azure Functions machines)
- use of custom steps like Paket or Fake requires manual upload to the hosting machine to `tools` folder for them to work.
- if we want to change the build process we have to change the `.deployment` and `deploy.cmd` files and checking them into our repository. So from now on, we are responsible for maintaining and troubleshooting them, not Microsoft. Also, there is no point in looking for documentation for them (but they are quite easy batch scripts).

### v2.0 - Azure Functions v2.0 
  
Azure Functions 2.0 (in beta at the time of writing) is Azure Functions running on Linux (the OS can be selected when creating the Function App):
![](/data/2018-01-01-The-missing-Azure-Functions-documentation/AzureFunctions2.png)

There are some changes/limitations compared to version 1.0:

- the OS is Linux
- runtime is .NET Core
- only C#, F#, JavaScript and Java is supported (Azure functions 1.0 supported Batch, C#, F#, JavaScript, PowerShell, Bash, Python, and TypeScript)
- ~~there is no consumption plan billing (as of the time of writing, but I'm sure that one will be offered they go to stable)~~ (apparently this is a false assumption - look at the comments)

Of course, there are some benefits:

- .NET  Core is faster and consumes less memory. It is a significant benefit since in Azure Functions we are paying for execution time and used memory so expect a lower bill.
- I suspect Linux offering will be a bit cheaper (VM with Linux tend to be less expensive)

## Summary

Azure Functions is evolving fast so make sure to look at the date when project/documentation/blog post was recently updated.          
  