# Implementation based on Markus Kuppe's
# https://github.com/lemmy/BlockingQueue/blob/master/impl/producer_consumer.c

using .Threads
import Base.@lock
import Base.Threads.@spawn

global buff_size    = 3
global numProducers = 3
global numConsumers = 3
global fillIndex    = 0
global useIndex     = 0
global count        = 0
global useIndex     = 0
global count        = 0
global buffer = collect(1:100)  

global buffer_lock = ReentrantLock()
global buffer_isempty = Event()
global buffer_isfull = Event()

function buff_append!(buffer, value)
    buffer[fillIndex] = value
    fillIndex = (fillIndex + 1) % buff_size
    count -= 1
end

function buff_head!(buffer)
    tmp = buffer[useIndex]
    useIndex = (useIndex + 1) % buff_size
    count -= 1
    tmp
end

function producer()
    println("I'm producer $(threadid())")
    while true
        @lock buffer_lock begin
            while count == buff_size
                wait(buffer_isempty)
            end
            buff_append!(buffer, rand(1:10))
            notify(buffer_isfull)
        end # lock is freed here
    end
end

function consumer()
    id = threadid()
    report = 0
    println("I'm consumer $(threadid())")
    
    while true
        @lock buffer_lock begin
            while count == 0
                wait(buffer_isfull)
            end
            buff_head!(buffer)
            notify(buffer_isfull)
        end
        if (report += 1) % 100 == 0
            println("$report values consumed by $id")
        end
    end
end

function main(buffer_size, numProducers, numConsumers)
    println("Buffer size = $buffer_size, Producers = $numProducers, Consumers = $numConsumers")
    @sync begin
        @async for _ in 1:numProducers
            @spawn producer()
        end
        @async for _ in 1:numConsumers
            @spawn consumer()
        end
    end
end

main(20,3,3)
