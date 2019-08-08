---
layout: post
title: Developers perspective on PowerShell Desired State Configuration
description: "All the things I wish someone told me before I've started using PowerShell Desired State Configuration"
modified: 2017-03-06
tags: [.NET,Windows, PowerShell, PowerShell DSC, DSC, Desired State Configuration, TeamCity, Hyper-V]
image:
  feature: data/2017-03-06-Developers-perspective-on-PowerShell-Desired-State-Configuration/logo.jpg
---

Configuration as code movement isn't anything new and is here to stay. I haven't had time to actually do a from zero to the desired state configuration script until a few weeks ago. Below are my thoughts after three weeks with PowerShell Desired State Configuration.
<!--MORE-->


## What I wanted to do

First, let me describe the goal I've set before myself.<br/>
I wanted to write a script that would go from a clean Windows machine to a fully configured TeamCity server with SQL Server storage and two build agents running. This may not be the ideal use case for PowerShell DSC, but:

- I don't know a better way to accomplish this with code as configuration. I could use a VM template, but this misses the point of being able to quickly respond to new versions of any of the dependencies. 
- I like PowerShell, and it is a very powerful tool, and DSC seemed OK for this task

## My thoughts
How did it end? It was an up and down journey, sometimes being frustrated, other times astounded by how powerful it is. Here are the main thoughts that I wish someone would tlll me earlier:
 
### You are not in developer land anymore. Different rules apply here!

We, as developers are used to the fact that we are operating on functions doing simple things like write to a file, save to a database, call over HTTP. When doing any system configuration we are operating on a bit higher level: install SQL Server, create w Windows user, install TeamCity build agent... <br/> 
What it implies? A LOT more things can go wrong, and not just because your code is wrong, but some external assumption were not met. <br/>
Here learn to look for causes not only in Your code but in the whole system.

{% include /newsletter.html %}

### Leaky abstraction and an unmet promise

Take this code:

```powershell
    WindowsFeature dotNetFramework35{
        Name="NET-Framework-Core"
        Ensure ="Present"
    }
```

It will check if .NET Framework 3.5 is installed on a machine, if not it will install it. Everything works great. Run it again and it does nothing because the framework is already present.

Now take this code:

```powershell
    xSQLServerSetup($Node.NodeName){
        DependsOn = "[WindowsFeature]dotNetFramework35","[xMountImage]mountedSql","[xWaitForVolume]waitVolume"
        SetupCredential = $account
        SourcePath = "E:\"
        SourceFolder = ""
        InstanceName = "SQLEXPRESS"
        Features = "SQLENGINE,SSMS,ADV_SSMS"
        SecurityMode = "SQL"
        SQLUserDBDir = "D:\SQL\Data"
    }
```

The code above will install Microsoft SQL Server with SQL Server Management Studio and SQL Server Profiler. Run it again and it does nothing because SQL Server is present. So what is the fuzz about?  

PowerShell DSC promises to be something more than an install script. This suppose to be a tool that will take the current system, sprinkle some magic, wave a wand and transform into what is in the script. And this is where the abstraction starts to get leaky. <br/>
Changing the `SQLUserDBDir` or `SecurityMode` and running the script again will succede, but won't change anything. Is it a game-over problem? For me, no, but it was a "there is no Santa" moment for me. 

> To be  precise:
> 
> - this was the situation in the time when I was using it
> - it is an `x` package and what it means it is still experimental.
> - `xSQLServerSetup` has 40 parameters that can be set. It is a complex piece of code, so I fully understand that it will take some time to implement all the edge cases
> - the package is very powerful and I am very happy that it exists. Big thanks to the people behind it.     

### Use a Virtual Machine

Writing a script on a bare metal machine is the fastest way to throw the computer out of the window. Why?<br/>
Let's take the example above. You run the script, change it, run again - it passes, but without applying the changes. So You uninstall SQL Server and run the script again. This is when the output transforms from white to a wall of red. Why? Because SQL Server doesn't do a clean uninstall (database catalogs aren't being removed. This is a good thing). So when trying to run an unsupervised install (no GUI) it fails because the installer asks if it should use this catalog or a new from scratch.

My method of working was to take snapshots of the VM from Hyper-V manager after finishing each step. It takes few seconds to take and restore the snapshot. Highly recommend doing so.

### The community is awesome

Before writing anything first google it! The number of packages is really impressive. If I had to point out one thing that really astounded me it would be the community behind DSC. I tried to return the favor and added some changes to [cTeamCityAgent](https://github.com/girwin/teamcity-agent-dsc) allowing to install multiple TeamCity agents.

Also, don't limit Yourself to packages from the official feed. There are many packages on Github that aren't available on the feed. 

### Error messages

A To contrast the best thing with the worst - error messages. They are terrible and in most cases don't give even a hint what went wrong (especially in the more complex modules). All they say is that the step failed. 

### Use Chocolatey

If You want to install/need a dependency from some application use [Chocolatey](http://chocolatey.org) module to install it:

```powershell
    cChocoPackageInstaller installJava{
        Name="jre8"
    }
``` 

Yup, that is all that is needed for installing Java Runtime. Simple as that!

### Script block is Your last resort

When there is no module to be found You can always fall back to `Script` block that allows executing any PowerShell. This one unzips TeamCity using 7zip: 

```powershell
Script unpackTeamCityGzip{
    GetScript = { @(Result = "Nie ma tu nic ciekawego") }
    SetScript = { & 'C:\Program Files\7-Zip\7z.exe' e  C:\temp\teamCity.tar.gz -oc:\temp }
    TestScript = { (Test-Path "c:\temp\teamCity.tar") }
    DependsOn = "[cRemoteFile]teamCityTarGzDownload"
}
```

### Intelisense

Packages are self-describing, so IntelliSense works even with new packages. In PowerShell ISE and VS Code.

### No restore packages

DSC consists of multiple packages. If You want to use the package it should be included in the script:

```powershell
Import-DscResource -ModuleName xSQLServer
```

What annoys me is the fact that there is no way to install referenced packages. To put it simply there is no `Nuget - restore`. You have to have a separate file that will take care of the installation. Something like this:

```powershell
Install-PackageProvider -Name "Nuget"
Install-Module xSQLServer 
```

This is annoying and error prone.

## Final thoughts

First and most important: **Did I write the script and did it work?**<br/> 
The answer is Yes.<br/>
**Writing it for the second time would I use PowerShell DSC?**<br/>
Again Yes.<br/>

It has some rough edges, leaky abstractions and there are things to fix, or make better, but it is a good product. 