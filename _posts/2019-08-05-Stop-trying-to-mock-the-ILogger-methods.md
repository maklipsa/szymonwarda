---
layout: post
title: Stop trying to mock the ILogger methods
description: ""
modified: 2019-08-05
tags: [testing, SOLID, .net]
image:
  feature: data/2019-08-05-Stop-trying-to-mock-the-ILogger-methods/logo.jpg
---

This post is so that I won't have to explain for the n-th time the same. 
Here it goes: 

Please stop trying to mock the ILogger methods from .net core.

Here is why:

<!--MORE-->

# It is not designed to be mocked

Most ILogger methods used in code are extension methods. Meaning static methods. While mocking them is possible using [Prig](https://github.com/urasandesu/Prig), or [Microsoft Fakes](https://docs.microsoft.com/en-US/visualstudio/test/code-generation-compilation-and-naming-conventions-in-microsoft-fakes?view=vs-2019) it is not pleasant.
Sice mocking a static method boils down to replacing the code **at runtime** using the debugger API those tests have limitations that may make them impossible to run on a CI server.

# Why test calling a logg method?

A log is a technical detail. They should be used for diagnosing problems and not much else.
The most common reason I see why people want to mock the Logger interface is because they are using the Logger to write audit data to an audit file using a Logger.

This might sound like a good idea, but is wrong for a few reasons:

- audit data should not be storred in a file. It can be exported to a file, but a file should not be it main storage.
- loggers are optimized for throughput, not consistency. They might loose data.
- writing to a [file is not (it can be, but don't do it) transactional](/What-is-the-simplest-database/).
- most logger use a buffer or a delayed/async write. Writing to a file is a slow IO operations, so loggers delay it not to slow down the process and write asynchroniously in batches. 
- what is written to a file is dependant on the logger configuration (appenders/sinks, minimal log level etc). Logger configuration should be customised for the environment where it is deployed this makes the test meaningless. 

For the reasons above verifying that a method is called does not guarantee that the information will be written to a file. And writing to a file is what want to verify. 

# You are testing the wrong thing

Even if we could test the Logger call, we still shouldn't do it. When testing if a business process logs some information we should be testing the if it called a method representing the intent, not the actuall logger call.
Let show an example. Let's imagine we are logging user logins.


```csharp
    public class UserService
    {
        private ILogger _logger;

        public UserService(ILogger logger)
        {
            _logger = logger;
        }

        public bool IsExistingUser(string userName)
        {
            _logger.LogInformation($"User:{userName} logged in.");
            // do some cerification logic
        }
    }
```

In this case it might look reasonable to try to mock the `LogInformation` to verify if it was called. But then we would be testing if the method was called, not the intent of logging a user trying to login. 
In this case those two are the same. If we split them our work will be much easier:

```csharp
    public class UserService
    {
        private ILogger _logger;

        public UserService(ILogger logger)
        {
            _logger = logger;
        }

        public bool IsExistingUser(string userName)
        {
            LogLoginTry(userName);
            // do some cerification logic
        }
		
		internal virtual void LogLoginAttempt(string userName){
		    _logger.LogInformation($"User:{userName} logged in.");
		}
    }
```

This can be easilly tested like this:

```csharp
    public class UserServiceTests
    {
        public void IsExistingUser_ShouldLogLogginAttempt()
        {
            // Arrange
            var userName = "testUser";
            var userService = new Mock<UserService>(null);
			userService.CallBase = true;
            userService
                .Setup(a => a.LogLoginAttempt(It.IsAny<string>()))   
                ;

            // Act 
            userService.Object.IsExistingUser(userName);

            // Assert
            userService.Verify(a => a.LogLoginAttempt(userName), Times.Exactly(1));
        }
    }

```

A few things to note here.

Those who read the code will notice that I am mocking the system under test (my `UserService`). Let me explain:

- Yes, it will work.
- Yes, you can do such things.
- Yes, it is perfectly OK.
- The, `IsExistingUser` will be called thanks to setting `CallBase = true`


## Making it even better

Even better idea is to refactor the audit logging function into a class because it implementing a business requirement and should encapsulate how it is doing it.

# Conclusion

Testing is not only writing test code. It is also looking at the existing code and making it better. Is something is hard to test it means that it is badly written. 
Or you are trying to tests something that shouldn't be tested this way.