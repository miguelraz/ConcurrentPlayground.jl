module Wire
    mutable struct Sender 
        acc::Int
    end
    mutable struct Receiver
        acc::Int
    end



    # test No Overdrafts
    # @test "No overdrafts" begin
    #     all(p.val >= 0 for p in people)
    # end

    function withdraw!(x::Sender, amount)
       x.acc -= amount 
    end

    function deposit!(x::Receiver, amount)
        x.acc += amount
    end

    function transact!(x::Sender, y::Receiver, amount)
        @sync begin
            @async withdraw!(x, amount)
            @async deposit!(y, amount)
        end
    end

    function main(account = 5, amount = 3)
        alice = Sender(account)
        bob = Receiver(account)

        transact!(alice, bob, amount)
    
        return all(p.acc >= 0 for p in (alice, bob))
    end


end

using .Wire
Wire.main()
