
const State = Dict
struct Environment
    var_bindings::Dict{Variable, Union{Variable, HOPPLLiteral}} # variable in this case can only be user-defined proc
    procs::Dict{String, FunctionDeclaration}
    function Environment()
        return new(Dict{Variable, HOPPLLiteral}(), Dict{String, FunctionDeclaration}())
    end
end
function Environment(program::Program)
    env = Environment()
    for proc in program.procs
        env.procs[proc.name] = proc
    end
    return env
end

abstract type Sampler end

function evaluate(exp::HOPPLLiteral, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    return exp
end

function evaluate(exp::Variable, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    if exp.name in PRIMITIVES
        return exp
    end
    if haskey(env.procs, exp.name)
        if haskey(env.var_bindings, exp)
            # local variable is boudn to same name, takes precedence over user proc
            return env.var_bindings[exp]
        end
        return exp
    end
    return env.var_bindings[exp]
end

function evaluate(exp::Let, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    c = evaluate(exp.binding, state, env, sampler)
    prev_value = get(env.var_bindings, exp.v, missing)
    env.var_bindings[exp.v] = c
    e = evaluate(exp.body, state, env, sampler)
    if ismissing(prev_value)
        delete!(env.var_bindings, exp.v) # no longer bound to value
    else
        env.var_bindings[exp.v] = prev_value # retain previous value (outer scope)
    end
    return e
end

function evaluate(exp::IfStatement, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    e = evaluate(exp.condition, state, env, sampler)
    if e == BoolLiteral(true) || e == IntLiteral(1)
        return evaluate(exp.holds, state, env, sampler)
    elseif e == BoolLiteral(false) || e == IntLiteral(0)
        return evaluate(exp.otherwise, state, env, sampler)
    else
        error("If condition does not evaluate to boolean.")
    end
end

function evaluate(exp::FunctionCall, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    cs = HOPPLExpression[]
    for arg in exp.args
        c = evaluate(arg, state, env, sampler)
        push!(cs, c)
    end
    h = evaluate(exp.head, state, env, sampler) # evaluates to variable if primitive or proc
    if h isa Variable
        if h.name in PROCS
            func = PROC2FUNC[exp.head.name]
            return func(cs...)
        elseif h.name in DISTRIBUTIONS
            return FunctionCall(h, cs) # return distribution "object" with evaluated args
        elseif haskey(env.procs, h.name)
            proc = env.procs[h.name]
            @assert length(proc.args) == length(cs)
            prev_values = Dict{Variable, Union{HOPPLLiteral, Variable, Missing}}()
            for (v, c) in zip(proc.args, cs)
                prev_values[v] = get(env.var_bindings, v, missing)
                env.var_bindings[v] = c
            end
            e = evaluate(proc.body, state, env, sampler)
            for v in proc.args
                prev_value = prev_values[v]
                if ismissing(prev_value)
                    delete!(env.var_bindings, v) # variable not bound to value anymore
                else
                    env.var_bindings[v] = prev_value # retain previous value (outer scope)
                end
            end
            return e
        else
            error("Unkown function. $h")
        end
    else
        error("Function head does not evaluate to name.")
    end
end

function evaluate(exp::VectorLiteral, state::State, env::Environment, sampler::Sampler)::HOPPLExpression
    cs = HOPPLExpression[]
    for x in exp.v
        c = evaluate(x, state, env, sampler)
        push!(cs, c)
    end
    return VectorLiteral(cs)
end

struct DeterministicSampler <: Sampler end

function evaluate(exp::SampleStatement, state::State, env::Environment, sampler::DeterministicSampler)::HOPPLExpression
    error("Encountered sample in DeterministicSampler.")
end

function evaluate(exp::ObserveStatement, state::State, env::Environment, sampler::DeterministicSampler)::HOPPLExpression
    error("Encountered observe in DeterministicSampler.")
end

function evaluate_program(program::Program, env=Environment(), state=State(), sampler=DeterministicSampler())
    for proc in program.procs
        env.procs[proc.name] = proc
    end

    r = evaluate(program.main, state, env, sampler)
    return r
end