#=
IS

E_{ Q(X) }[ p(X|Y) / Q(X) * r(X) ]

W = p(X,Y) / Q(X) = p(Y) * p(X|Y) / Q(X) 

E_{ Q(X) }[ p(X|Y) / Q(X) * r(X) ] = 1/p(Y) E_{ Q(X) }[ W * r(X) ] 

p(Y) = E_{ Q(X) }[ p(X,Y) / Q(X)] = E_{ Q(X) }[ W ] 

likelihood weighting

for p(X,Y) = ∏ p(x|X,Y) ∏ p(y|X,Y)
q(X) = ∏ p(x|X,Y) - distribution in sample - != p(X)   in marginal probability sense
=> W = ∏ p(y|X,Y) - collected in observe   - != p(Y|X) in marginal probability sense 

=#

mutable struct IS <: Sampler
    N::Int
    Q::Union{Dict{Address, Distribution}, Nothing}

    i::Int

    function IS(N::Int; Q=nothing)
        this = new()
        this.N = N
        this.Q = Q
        this.i = 0

        return this
    end
end

function reset!(sampler::IS)
    sampler.i = 0
end
function step!(sampler::IS)
    sampler.i += 1
end

function evaluate(exp::SampleStatement, state::State, env::Environment, sampler::IS)::HOPPLExpression
    d = evaluate(exp.dist, state, env, sampler)
    if !isnothing(sampler.Q)
        q = get(sampler.Q, exp.address, d)
    else
        q = d # likelihood weighting
    end

    c = sample(q)
    state["logW"] = state["logW"] + logprob(d, c) - logprob(q, c) # == state["logW"] if c == d

    return c
end

function evaluate(exp::ObserveStatement, state::State, env::Environment, sampler::IS)::HOPPLExpression
    d = evaluate(exp.dist, state, env, sampler)
    c = evaluate(exp.observation, state, env, sampler)
    state["logW"] = state["logW"] + logprob(d, c)

    return c
end

function infer(program::Program, sampler::IS)
    rs = Vector{HOPPLExpression}(undef, sampler.N)
    lp = Vector{Float64}(undef, sampler.N)

    env = Environment(program)
    state = State("logW" => 0.0)

    reset!(sampler)

    for i in 1:sampler.N
        step!(sampler)

        state["logW"] = 0.0
        empty!(env.var_bindings)
        r = evaluate(program.main, state, env, sampler)

        @inbounds rs[i] = r
        @inbounds lp[i] = state["logW"]
    end

    return lp, to_julia.(rs)
end
