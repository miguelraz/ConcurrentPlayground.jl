# ConcurrentPlayground.jl

This is a Julia port of Markus Kuppe's workshop [Weeks of Debugging Can Save You Hours of TLA+](https://www.youtube.com/watch?v=wjsI0lTSjIo&t=549s)

The task is relatively simple:

There is a C code implementation for a [Multiple Consumers Multiple Producers](https://github.com/lemmy/BlockingQueue/blob/master/impl/producer_consumer.c) [Blocking Queue](https://github.com/lemmy/BlockingQueue) that was working fine for months and then one day in production in blew up and you have to find the deadlock.

The point is to match Julia semantics side by side with a TLA+ implementation to explore dataraces, deadlock freedom, livelock freedom, starvation guarantees, play around with the new Julia atomic semantics... all the good stuff.

We start with `mpmpc0.jl`, the first attempt at porting the C code linked above.. Each implementation describes the tweaks from the previous versions and the output when run.

You can try and look at the code and figure out what went wrong before reading the diagnoses, or try to come up with your own TLA+ spec after looking at the code.

*Note*: implementation hand crafted mutexes is a good learning experience, but you wouldn't want to use this in production. Data structures like [Channels](https://docs.julialang.org/en/v1/manual/asynchronous-programming/#Communicating-with-Channels) provide these abstractions safely and with a friendly API. The point is to develop a specification for a concurrent algorithm alongside a Julia implementation and work towards establishing desirable properties of the algorithm. I also recommend checking out the [JuliaFolds organization](https://juliafolds.github.io/data-parallelism/tutorials/concurrency-patterns/) which is building exciting tooling around concurrency in Julia.

If you don't know where to get started with TLA+, check out [Hillel Wayne's website, learntla.com](learntla.com) or [Leslie Lamport's (TLA+'s creator) website](https://lamport.azurewebsites.net/tla/tla.html).

Happy Hacking!

--------

## Vocabulary P0

There's a lot of programming idioms native to concurrent algorithms that are standardized from C idioms but look just a lil' bit different in Julia. Here's a table of the ones we will be using, and how we use them.

| *C idiom* | *Julia idiom* | *Meaning* | 
--- | --- | ---
| `pthread_mutex_t mutex;` | `global buffer_lock = Reentrantlock() ` | Create a mutex called `buffer_lock` which threads will need to obtain in order to access the array `buffer`. There's other types of locks like `SpinLock` but that's not our concern right now. |
| `pthread_cond_t empty` | `global buffer_isempty = Threads.Condition(buffer_lock)` | Create a thread-safe event source that threads can wait for. This will let us put different workers to wait for the buffer being empty/full and then carrying out work. `Condition` can "flip" states many times, `Event`s only "flip" once. See `?Threads.Condition` for more info. |
| `while (1) { assert(pthread_mutex_lock(&mutex) == 0); ... }` | ` while true @lock buffer_lock begin ... end end` | Continually try to take the lock called `mutex/buffer_lock`. When you do, go to the body of the while loop. |
| `pthread_cond_wait(&empty, &full)` | `wait(buffer_isfull)` | This thread will wait until the `buffer_isfull` condition is signalled |
| `pthread_cond_signal(&full)` | `notify(buffer_isfull)` | This thread will notify the `Condition` `buffer_isfull` that it should flip to `true` |
| `pthread_mutex_unlock(&mutex);` | `unlock(buffer_lock)`, or implicit. | Release the `mutex`/`lock` this thread has on `buffer_lock` if you use `@lock buffer_lock expression`, that unfolds to a try/finally block with `unlock` at the end. See the helpdocs for `?Base.@lock` for more info|



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

<details>
  <summary>Spoiler warning</summary>
    Some of the producers can also be consumers! That's not good! 
</details>