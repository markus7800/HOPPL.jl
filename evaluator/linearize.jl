
abstract type LinearHOPPLExpression end

mutable struct LinearHOPPL
    gs::GenSym
    program::Vector{LinearHOPPLExpression}
    function LinearHOPPL(gs::GenSym)
        return new(gs, LinearHOPPLExpression[])
    end
end

function Base.show(io::IO, linear::LinearHOPPL)
    print(io, "LinearHOPPL")
    for (i, exp) in enumerate(linear.program)
        print(io, "\n")
        print(io, "$i. ", exp)
    end
end

function add!(linear::LinearHOPPL, exp::LinearHOPPLExpression)::Int
    push!(linear.program, exp)
    return length(linear.program)
end

function next_linenumber(linear::LinearHOPPL)::Int
    return length(linear.program) + 1
end


mutable struct Literal <: LinearHOPPLExpression
    l::Union{HOPPLLiteral, Variable}
end


function Base.show(io::IO, exp::Literal)
    if l isa Variable
        print(io, "VARIABLE ", exp.l)
    else
        print(io, "LITERAL ", exp.l)
    end
end


function linearize(exp::HOPPLLiteral, linear::LinearHOPPL)
    add!(linear, Literal(exp))
end

function linearize(exp::Variable, linear::LinearHOPPL)
    add!(linear, Literal(exp))
end

# variable scoping

mutable struct Varbinding <: LinearHOPPLExpression
    v::Variable
    prev_value::HOPPLExpression # set at evaluation
    function Varbinding(v::Variable)
        this = new()
        this.v = v
        return this
    end
end

function Base.show(io::IO, exp::Varbinding)
    print(io, "BIND ", exp.v)
end

mutable struct Unbinding <: LinearHOPPLExpression
    binding::Varbinding
end

function Base.show(io::IO, exp::Unbinding)
    print(io, "UNBIND ", exp.binding.v)
end


function linearize(exp::Let, linear::LinearHOPPL)
    linearize(exp.binding, linear)
    binding = Varbinding(exp.v)
    add!(linear, binding)
    linearize(exp.body, linear) # continuation where we input c
    unbinding = Unbinding(binding)
    add!(linear, unbinding)
end

#(let [v (if true 1 2)] v)
mutable struct Branching <: LinearHOPPLExpression
    v::Variable
    holds::Int
    otherwise::Int
    function Branching(v::Variable)
        return new(v, 0, 0)
    end
end

function Base.show(io::IO, exp::Branching)
    print(io, "BRANCH ", exp.v, ": ", exp.holds, " - ", exp.otherwise)
end

mutable struct BranchEnd <: LinearHOPPLExpression
    next::Int
    function BranchEnd()
        return new(0)
    end
end

function Base.show(io::IO, exp::BranchEnd)
    print(io, "ENDBRANCH ", exp.next)
end

function linearize(exp::IfStatement, linear::LinearHOPPL)
    if !(exp.condition isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.condition, IfStatement(v, exp.holds, exp.otherwise))
        linearize(e, linear)
    else
        v = exp.condition
        branching = Branching(v)
        add!(linear, branching)
        branchend = BranchEnd()
        branching.holds = next_linenumber(linear)
        linearize(exp.holds, linear)
        add!(linear, branchend)
        branching.otherwise = next_linenumber(linear)
        linearize(exp.otherwise, linear)
        add!(linear, branchend)
        branchend.next = next_linenumber(linear)
    end
end

mutable struct Call <: LinearHOPPLExpression
    head::Variable
    args::Vector{Variable}
end

function Base.show(io::IO, exp::Call)
    print(io, "Call ", exp.head, ": ")
    for arg in exp.args
        print(io, arg, " ")
    end
end

function linearize(exp::FunctionCall, linear::LinearHOPPL)
    if !(exp.head isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.head, FunctionCall(v, exp.args))
        linearize(e, linear)
    else
        if !all(arg isa Variable for arg in exp.args)
            for (i, arg) in enumerate(exp.args)
                if !(arg isa Variable)
                    v = next_var!(linear.gs)
                    # exp = deepcopy(exp)
                    exp.args[i] = v
                    e = Let(v, arg, exp)
                    linearize(e, linear)
                    return
                end
            end
        else
            add!(linear, Call(exp.head, exp.args))
        end
    end
end

function linearize(exp::VectorLiteral, linear::LinearHOPPL)
    if !all(el isa Variable for el in exp.v)
        for (i, el) in enumerate(exp.v)
            if !(el isa Variable)
                v = next_var!(linear.gs)
                # exp = deepcopy(exp)
                exp.v[i] = v
                e = Let(v, el, exp)
                linearize(e, linear)
                return
            end
        end
    else
        add!(linear, Literal(exp))
    end
end


mutable struct Sample <: LinearHOPPLExpression
    address::Variable
    dist::Variable
end

function Base.show(io::IO, exp::Sample)
    print(io, "SAMPLE ", exp.dist, " at ", exp.address)
end

function linearize(exp::SampleStatement, linear::LinearHOPPL)
    if !(exp.address isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.address, SampleStatement(v, exp.dist))
        linearize(e, linear)
    elseif !(exp.dist isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.dist, SampleStatement(exp.address, v))
        linearize(e, linear)
    else
        add!(linear, Sample(exp.address, exp.dist))
    end
end

mutable struct Observe <: LinearHOPPLExpression
    address::Variable
    dist::Variable
    observation::Variable
end

function Base.show(io::IO, exp::Observe)
    print(io, "OBSERVE ", exp.observation, " for ", exp.dist, " at ", exp.address)
end


function linearize(exp::ObserveStatement, linear::LinearHOPPL)
    if !(exp.address isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.address, ObserveStatement(v, exp.dist, exp.observation))
        linearize(e, linear)
    elseif !(exp.dist isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.dist, ObserveStatement(exp.address, v, exp.observation))
        linearize(e, linear)
    elseif !(exp.observation isa Variable)
        v = next_var!(linear.gs)
        e = Let(v, exp.observation, ObserveStatement(exp.address, exp.dist, v))
        linearize(e, linear)
    else
        add!(linear, Observe(exp.address, exp.dist, exp.observation))
    end
end


