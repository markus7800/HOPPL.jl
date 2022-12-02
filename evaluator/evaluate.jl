abstract type Sampler end

# mutable struct IS <: Sampler
# end

mutable struct ForwardSampler <: Sampler
end

function sample(sampler::ForwardSampler, address::String, d::Distribution)::Tuple{HOPPLLiteral, Symbol}
    value = sample(d)
    return value, :continue
end

function observe(sampler::ForwardSampler, address::String, d::Distribution, observation::HOPPLLiteral)::Tuple{HOPPLLiteral, Symbol}
    return observation, :continue
end

struct Environment
    var_bindings::Dict{Variable, Union{HOPPLLiteral, Distribution}}
    function Environment()
        return new(Dict{Variable, Union{HOPPLLiteral, Distribution}}())
    end
end

struct CallStackEntry
    proc::String
    caller::String
    called_at::Int
end

mutable struct Evaluator
    program::LinearHOPPLProgram
    env::Environment
    current_line::Int
    current_proc::String
    call_stack::Vector{CallStackEntry}
    ret::Union{HOPPLLiteral, Distribution}
    sampler::Sampler

    function Evaluator(program::LinearHOPPLProgram, sampler::Sampler, env=Environment())
        return new(
            program,
            env,
            1,
            "main",
            CallStackEntry[CallStackEntry("main", "root", 0)],
            EmptyExpression(),
            sampler
        )
    end
end


function evaluate(e::Evaluator)::Union{HOPPLLiteral, Distribution}
    while true
        proc = e.current_proc == "main" ? e.program.main : e.program.procs[e.current_proc]
        if e.current_line > length(proc)
            # end of procedure reached
            call = pop!(e.call_stack)
            if call.proc == "main"
                # end of program reached
                break
            else
                # go to place where proc was called
                e.current_line = call.called_at
                e.current_proc = call.caller
            end
        else
            line = proc[e.current_line]
            instruction, next_proc, next_line = evaluate(e, line)
            e.current_line = next_line
            e.current_proc = next_proc

            if instruction == :continue
                # continue evaluation
            elseif instruction == :interrupt
                break
            end
        end
    end

    return e.ret
end

function reset!(e::Evaluator)
    e.current_line = 1
    e.current_proc = "main"
    e.call_stack = CallStackEntry[CallStackEntry("main", "root", 0)]
    e.ret = EmptyExpression()
    empty!(e.env.var_bindings)
end

function evaluate(e::Evaluator, i::Literal)::Tuple{Symbol, String, Int}
    if i.l isa Variable
        e.ret = e.env.var_bindings[i.l]
    else
        e.ret = i.l
    end
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Varbinding)::Tuple{Symbol, String, Int}
    i.prev_value = get(e.env.var_bindings, i.v, missing)
    e.env.var_bindings[i.v] = e.ret
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Unbinding)::Tuple{Symbol, String, Int}
    prev_value = i.binding.prev_value
    if ismissing(prev_value)
        delete!(e.env.var_bindings, i.binding.v)
    else
        e.env.var_bindings[i.v] = prev_value
    end
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Branching)::Tuple{Symbol, String, Int}
    if i.v == BoolLiteral(true) || e.env.var_bindings[i.v] == BoolLiteral(true)
        return :continue, e.current_proc, i.holds
    else
        return :continue, e.current_proc, i.otherwise
    end
end

function evaluate(e::Evaluator, i::BranchEnd)::Tuple{Symbol, String, Int}
    return :continue, e.current_proc, i.next
end

function evaluate(e::Evaluator, i::Call)::Tuple{Symbol, String, Int}
    cs = HOPPLLiteral[]
    for arg in i.args
        if arg isa Variable
            c = e.env.var_bindings[arg]
        else
            c = arg
        end
        push!(cs, c)
    end

    if i.head.name in PROCS
        func = PROC2FUNC[i.head.name]
        e.ret = func(cs...)
        return :continue, e.current_proc, e.current_line+1

    elseif i.head.name in DISTRIBUTIONS
        e.ret = dist_from(i.head.name, cs)
        return :continue, e.current_proc, e.current_line+1

    elseif haskey(e.program.procs, i.head.name)
        proc_args = e.program.proc_args[i.head.name]
        i.prev_values = Dict{Variable, Union{HOPPLLiteral, Missing}}()
        for (v, c) in zip(proc_args, cs)
            i.prev_values[v] = get(e.env.var_bindings, v, missing)
            e.env.var_bindings[v] = c
        end
        push!(e.call_stack, CallStackEntry(i.head.name, e.current_proc, e.current_line))
        return :continue, i.head.name, 1

    else
        error("Unkown function. $(i.head)")
    end
end

function evaluate(e::Evaluator, i::Sample)::Tuple{Symbol, String, Int}
    d = e.env.var_bindings[i.dist]
    if i.address isa Variable
        address = e.env.var_bindings[i.address]
    else
        address = i.address
    end

    value, instruction = sample(e.sampler, address.s, d)
    e.ret = value

    return instruction, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Observe)::Tuple{Symbol, String, Int}
    d = e.env.var_bindings[i.dist]
    if i.address isa Variable
        address = e.env.var_bindings[i.address]
    else
        address = i.address
    end
    if i.observation isa Variable
        observation = e.env.var_bindings[i.observation]
    else
        observation = i.observation
    end

    value, instruction = observe(e.sampler, address.s, d, observation)
    e.ret = value

    return instruction, e.current_proc, e.current_line+1
end