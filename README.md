# ConcurrentPlayground.jl

This is a Julia port of Markus Kuppe's workshop [Weeks of Debugging Can Save You Hours of TLA+](https://www.youtube.com/watch?v=wjsI0lTSjIo&t=549s)

The task is relatively simple:

There is a C code implementation for a [Multiple Consumers Multiple Producers](https://github.com/lemmy/BlockingQueue/blob/master/impl/producer_consumer.c) that was working fine for months and then one day in production in blew up and you have to find the deadlock.

The point is to match Julia semantics side by side with a TLA+ implementation to explore dataraces, deadlock freedom, livelock freedom, starvation guarantees, play around with the new Julia atomic semantics... all the good stuff.

We start with `mpmpc0.jl`, the first attempt at porting the C code linked above.. Each implementation describes the tweaks from the previous versions and the output when run.

You can try and look at the code and figure out what went wrong before reading the diagnoses, or try to come up with your own TLA+ spec after looking at the code.

If you don't know where to get started with TLA+, check out [Hillel Wayne's website, learntla.com](learntla.com) or [Leslie Lamport's, its creator's website](https://lamport.azurewebsites.net/tla/tla.html).

Happy Hacking!

---------

## mpmc0

The first attempt at porting the C code. Unfortunately (or fortunately, if you want to learn this stuff), the code already has a deadlock, and not the one we are looking for!
When running `main(3,3,3)`, we get

```julia
julia> main(3,3,3)
Buffer size = 3, Producers = 3, Consumers = 3
I'm producer 3
I'm producer 3
I'm consumer 8
I'm producer 7
I'm consumer 7
I'm consumer 7
```

Which will probably look different on your machine, but the behaviour is the following: the producers and consumers rev up, but none start doing work. 

Can you spot what's wrong with just this printout?

```spoiler 💥
Some of the producers can also be consumers! That's not good! 
```
