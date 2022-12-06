abstract type Sampler end

# mutable struct IS <: Sampler
# end

mutable struct ForwardSampler <: Sampler
end

function sample(sampler::ForwardSampler, address::String, d::Distribution)::Tuple{HOPPLLiteral, Symbol}
    value = sample(d)
    # println("sample ", value)
    return value, :continue
end

function observe(sampler::ForwardSampler, address::String, d::Distribution, observation::HOPPLLiteral)::Tuple{HOPPLLiteral, Symbol}
    return observation, :continue
end

struct Environment
    var_bindings::Dict{String, Union{HOPPLLiteral, Distribution}}
    function Environment()
        return new(Dict{String, Union{HOPPLLiteral, Distribution}}())
    end
end

function Base.getindex(env::Environment, v::Variable, scope::String)
    return env.var_bindings[v.name * "_" * scope]
end

# function Base.get(env::Environment, v::Variable, scope::String, default)
#     return get(env.var_bindings, v.name * "_" * scope, default)
# end

function Base.setindex!(env::Environment, value::Union{HOPPLLiteral, Distribution}, v::Variable, scope::String)
    env.var_bindings[v.name * "_" * scope] = value
end

function Base.delete!(env::Environment, v::Variable, scope::String)
    delete!(env.var_bindings, v.name * "_" * scope)
end

struct CallStackEntry
    id::String
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
    stack_gs::GenSym
    ret::Union{HOPPLLiteral, Distribution}
    sampler::Sampler

    function Evaluator(program::LinearHOPPLProgram, sampler::Sampler, env=Environment())
        return new(
            program,
            env,
            1,
            "main",
            CallStackEntry[CallStackEntry("main", "main", "root", 0)],
            GenSym(),
            EmptyExpression(),
            sampler
        )
    end
end

function infer(program::Program, sampler::Sampler, N::Int)::Vector{HOPPLLiteral}
    linear_program = LinearHOPPLProgram(program)
    return infer(linear_program, sampler, N)
end

function infer(program::LinearHOPPLProgram, sampler::Sampler, N::Int)::Vector{HOPPLLiteral}
    evaluator = Evaluator(program, sampler)
    res = Vector{HOPPLLiteral}(undef, N)
    for i in 1:N
        reset!(evaluator)
        r = evaluate(evaluator)
        res[i] = r
    end
    return res
end

function evaluate(e::Evaluator)::Union{HOPPLLiteral, Distribution}
    while true
        if length(e.call_stack) >= 1000
            error("Recursion limit.")
        end

        proc = e.current_proc == "main" ? e.program.main : e.program.procs[e.current_proc]
        scope = e.call_stack[end].id

        if e.current_line > length(proc)
            # end of procedure reached
            call = pop!(e.call_stack)
            # println("End of scope $(call.id) reached.")
            if call.proc == "main"
                # end of program reached
                break
            else
                # unbind procedure arguments
                for arg in e.program.proc_args[e.current_proc]
                    delete!(e.env, arg, scope)
                end
                # go to place where proc was called
                e.current_line = call.called_at + 1
                e.current_proc = call.caller
            end
        else
            line = proc[e.current_line]
            # println("Scope $scope ", e.current_proc, " ", e.current_line, ": ", line)
            try
                instruction, next_proc, next_line = evaluate(e, line)
                e.current_line = next_line
                e.current_proc = next_proc

                if instruction == :continue
                    # continue evaluation
                elseif instruction == :interrupt
                    break
                end
            catch e
                println(line)
                rethrow()
            end
        end
    end

    return e.ret
end

function reset!(e::Evaluator)
    e.current_line = 1
    e.current_proc = "main"
    e.call_stack = CallStackEntry[CallStackEntry("main", "main", "root", 0)]
    e.ret = EmptyExpression()
    e.stack_gs = GenSym()
    empty!(e.env.var_bindings)
end

function to_literal(e::Evaluator, scope::String, v::Variable)
    return e.env[v, scope]
end

function to_literal(e::Evaluator, scope::String, vl::VectorLiteral)
    return VectorLiteral([to_literal(e, scope, el) for el in vl.v])
end

function to_literal(e::Evaluator, scope::String, v::HOPPLExpression)
    return v
end


function evaluate(e::Evaluator, i::Literal)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    e.ret = to_literal(e, scope, i.l)
    # println("return ", i.l, " ", scope, ": ", e.ret)
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Varbinding)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    e.env[i.v, scope] = e.ret
    # println("bind ", i.v, " ", scope, ": ", e.ret)
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Unbinding)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    # println("unbind ", i.binding.v, " ", scope)
    delete!(e.env, i.binding.v, scope)
    return :continue, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Branching)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    
    v = to_literal(e, scope, i.v)

    if v isa BoolLiteral && v.b
        return :continue, e.current_proc, i.holds
    elseif  v isa IntLiteral && v.i == 1
        return :continue, e.current_proc, i.holds
    else
        return :continue, e.current_proc, i.otherwise
    end
end

function evaluate(e::Evaluator, i::BranchEnd)::Tuple{Symbol, String, Int}
    return :continue, e.current_proc, i.next
end

function evaluate(e::Evaluator, i::Call)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    cs = HOPPLLiteral[]
    for arg in i.args
        # println(arg)
        c = to_literal(e, scope, arg)
        # println("c: ", c)
        push!(cs, c)
    end

    if i.head.name in PROCS
        func = PROC2FUNC[i.head.name]
        # println(cs)
        e.ret = func(cs...)
        return :continue, e.current_proc, e.current_line+1

    elseif i.head.name in DISTRIBUTIONS
        e.ret = dist_from(i.head.name, cs)
        return :continue, e.current_proc, e.current_line+1

    elseif haskey(e.program.procs, i.head.name)
        next_entry = CallStackEntry(next_str!(e.stack_gs), i.head.name, e.current_proc, e.current_line)
        next_scope = next_entry.id
        # println("New scope $(next_entry.id).")

        proc_args = e.program.proc_args[i.head.name]
        for (v, c) in zip(proc_args, cs)
            e.env[v, next_scope] = c
        end
        push!(e.call_stack, next_entry)
        return :continue, i.head.name, 1

    else
        error("Unkown function. $(i.head)")
    end
end

function evaluate(e::Evaluator, i::Sample)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    d = e.env[i.dist, scope]
    address = to_literal(e, scope, i.address)

    value, instruction = sample(e.sampler, address.s, d)
    e.ret = value

    return instruction, e.current_proc, e.current_line+1
end

function evaluate(e::Evaluator, i::Observe)::Tuple{Symbol, String, Int}
    scope = e.call_stack[end].id
    d = e.env[i.dist, scope]
    address = to_literal(e, scope, i.address)
    observation = to_literal(e, scope, i.observation)

    value, instruction = observe(e.sampler, address.s, d, observation)
    e.ret = value

    return instruction, e.current_proc, e.current_line+1
end