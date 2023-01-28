

mutable struct IS <: Sampler
    W::Float64
    Q::Union{Dict{String, Distribution}, Missing}
    function IS(Q=missing)
        return new(0.0, Q)
    end
end

function sample(sampler::IS, address::String, d::Distribution)::Tuple{HOPPLLiteral, Symbol}
    if !ismissing(sampler.Q)
        q = sampler.Q[address]
    else
        q = d
    end

    value = sample(q)
    sampler.W += logprob(d, observation) - logprob(q, value)

    return value, :continue
end

function observe(sampler::IS, address::String, d::Distribution, observation::HOPPLLiteral)::Tuple{HOPPLLiteral, Symbol}
    sampler.W += logprob(d, observation)
    return observation, :continue
end


function infer(program::LinearHOPPLProgram, sampler::IS, N::Int)
    evaluator = Evaluator(program, sampler)
    res = Vector{HOPPLLiteral}(undef, N)
    lp = Vector{Float64}(undef, N)
    for i in 1:N
        sampler.W = 0.0
        reset!(evaluator)
        r = evaluate(evaluator)
        res[i] = r
        lp[i] = sampler.W
    end
    return res, lp
end