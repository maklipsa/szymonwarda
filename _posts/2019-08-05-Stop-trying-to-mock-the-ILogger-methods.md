---
layout: post
title: Stop trying to mock the ILogger methods
description: "Testing is easy. If it starts to be hard, maybe change the code?"
modified: 2019-08-05
tags: [testing, SOLID, .net]
image:
  feature: data/2019-08-05-Stop-trying-to-mock-the-ILogger-methods/logo.jpg
---

I've seen multiple people struggling with trying to mock the ILogger calls. This post will hopefully save some people from wandering this path.
Here it goes:

<div class="center">
    <div class="button" >Please stop trying to mock the ILogger methods from .net core.</div>
</div>

Here is why:

<!--MORE-->

# It is not designed to be mocked

Most ILogger methods that we use for logging are extension methods - static methods. While mocking them is possible using [Prig](https://github.com/urasandesu/Prig), or [Microsoft Fakes](https://docs.microsoft.com/en-US/visualstudio/test/code-generation-compilation-and-naming-conventions-in-microsoft-fakes?view=vs-2019) it is not easy or pleasant.
Mocking a static method boils down to replacing the code **at runtime** using the debugger API. It sounds hard because it is hard. Those testing frameworks have additional restrictions that may make them impossible to run on a CI server.

# Why test calling a log method?

A log is a technical detail. It should be used for diagnosing problems and not much else.
The most common reason I see why people want to mock the `ILogger` interface is because they are using a logger to write audit data to an audit file using a logger.

It might sound like a good idea, but it is wrong for a few reasons:

- **Audit data should not be stored in a file**. It can be exported to a file, but a file should not be its main storage.
- **Loggers are optimized for throughput, not consistency**. They might lose data.
- **Writing to a [file is not (it can be, but don't do it) transactional](/What-is-the-simplest-database/)**. If we write to a log and then rollback the transaction, the entry will stay in the file.
- **Most loggers use a buffer or a delayed/async write**. Writing to a file is a slow IO operation. Loggers delay it not to slow down the process and write asynchronously in batches. 
- **Calling the logging method does not imply that the entry will be written to a file**. Loggers offer multiple ways to filter what will be written to which file. From log levels to disabling some loggers. Additionally, logging configurations are, in most cases, customized for each environment. Making the test meaningless. 

# You are testing the wrong thing

Even if we could test the `ILogger` call, we still shouldn't do it. Let me show an example. Let's imagine we are logging access to `RegisterUser`. Something like this:

```csharp
    public class UserService
    {
        private ILogger _logger;

        public UserService(ILogger logger)
        {
            _logger = logger;
        }

        public bool RegisterUser(RegisterData data)
        {
            _logger.LogInformation($"User:{data.UserName} logged in.");
            // do some cerification logic
        }
    }
```

It might look reasonable to try to mock the `LogInformation` of the `ILogger` to verify if the business process logs registration attempts.

When testing if a business process logs some information, we should be testing the **business intent**. 
By testing the `ILogger` call, we are testing the **implementation**. Those two are mixed in the code above, causing our problems.

{% include /newsletter.html %}

# Refactor

If we split the implementation from the intent, our work will be much more straightforward:

```csharp
    public class UserService
    {
        private ILogger _logger;

        public UserService(ILogger logger)
        {
            _logger = logger;
        }

        public bool RegisterUser(RegisterData data)
        {
            LogRegisterAttempt(userName);
            // do some cerification logic
        }
        
        internal virtual void LogRegisterAttempt(string userName){
            _logger.LogInformation($"User:{userName} tried to register.");
        }
    }
```

Now for a simple test (used Moq, but any mocking framework will do):

```csharp
    public class UserServiceTests
    {
        public void RegisterUser_ShouldLogLogginAttempt()
        {
            // Arrange
            var registerData = new RegisterData(){
                /*
                ...
                */
            };
            var userService = new Mock<UserService>(null);
            userService.CallBase = true;
            userService
                .Setup(a => a.LogRegisterAttempt(It.IsAny<RegisterData>()))   
                ;

            // Act 
            userService.Object.RegisterUser(registerData);

            // Assert
            userService.Verify(a => a.LogRegisterAttempt(registerData), Times.Exactly(1));
        }
    }

```

A few things to note here:

Those who read the code carefully will notice that I am mocking the system under test (my `UserService`). Let me explain:

- Yes, it will work (the method has to be virtual).
- Yes, you can do such things.
- Yes, it is perfectly OK.
- The `RegisterUser` will be called thanks to setting `CallBase = true`


## Making it even better

An even better idea is to refactor the audit logging function into a class. Since it is fulfilling a business need, so it should encapsulate how it is doing it.

## We aren't testing the same thing!

No, we aren't. We are missing one test. One that will call `LogRegisterAttempt`, read the log file and verify if it has the log entry - a simple integration test. I leave it to the reader ;)
 
# Conclusion

Testing is not only writing test code. It is also looking at the existing code and making it better. 

<div class="center">
    <div class="button" >
If something is hard to test, it means that it is badly written. <br/> 
<b>or</b>
<br/> You are trying to test something that shouldn't be tested in this way.</div>
</div>