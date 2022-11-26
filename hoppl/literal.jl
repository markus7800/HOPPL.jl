#=
HOPPL Literals are
- Variables, i.e. x
- Empty Expressions () (not really used)
- Strings, i.e. 'x'
- Booleans, true or false
- Integers, i.e. 1
- Floating point numbers, i.e. 1.23
- Vectors, i.e. [x, 'x', 1, 1.23]
=#

struct Variable <: HOPPLExpression
    name::String
end

function print_exp(io::IO, exp::Variable, tab::String="")
    print(io, tab, exp.name)
end

abstract type HOPPLLiteral <: HOPPLExpression end

function to_julia(exp::HOPPLLiteral)
    error("Not implemented")
end

struct EmptyExpression <: HOPPLLiteral
end

function print_exp(io::IO, exp::EmptyExpression, tab::String="")
    print(io, tab, "EMPTY")
end

function to_julia(exp::EmptyExpression)
    return nothing
end

struct StringLiteral <: HOPPLLiteral
    s::String
end

function print_exp(io::IO, exp::StringLiteral, tab::String="")
    print(io, tab, exp.s)
end

function to_julia(exp::StringLiteral)
    return exp.s
end

struct BoolLiteral <: HOPPLLiteral
    b::Bool
end

function print_exp(io::IO, exp::BoolLiteral, tab::String="")
    print(io, tab, exp.b)
end

function to_julia(exp::BoolLiteral)
    return exp.b
end

struct IntLiteral <: HOPPLLiteral
    i::Int
end

function print_exp(io::IO, exp::IntLiteral, tab::String="")
    print(io, tab, exp.i)
end

function to_julia(exp::IntLiteral)
    return exp.i
end

struct FloatLiteral <: HOPPLLiteral
    f::Float64
end

function print_exp(io::IO, exp::FloatLiteral, tab::String="")
    print(io, tab, exp.f)
end

function to_julia(exp::FloatLiteral)
    return exp.f
end

function to_julia(exp::Missing)
    return NaN
end

function compile_hoppl(c::Compiler, s::String)::HOPPLExpression
    try
        i = parse(Int, s)
        return IntLiteral(i)
    catch ArgumentError end
    try
        f = parse(Float64, s)
        return FloatLiteral(f)
    catch ArgumentError end
    try
        b = parse(Bool, s)
        return BoolLiteral(b) 
    catch ArgumentError end

    if s[1] == '\'' && s[end] == '\''
        return StringLiteral(s)
    else
        return Variable(s)
    end
end


struct VectorLiteral <: HOPPLLiteral
    v::Vector{HOPPLExpression}
end

Base.:(==)(l::VectorLiteral, r::VectorLiteral) = all(l.v .== r.v)

function print_exp(io::IO, exp::VectorLiteral, tab::String="")
    println(io, tab, "Vector [")
    for elem in exp.v
        print_exp(io, elem, tab*"  ")
        println(io)
    end
    print(io, tab, "]")
end

function to_julia(exp::VectorLiteral)
    return to_julia.(exp.v)
end

function compile_vector(c::Compiler, children::ParserChildren)::VectorLiteral
    @assert children[end] == "]" children
    v = Vector{HOPPLExpression}()
    for child in children[1:end-1]
        push!(v, compile_hoppl(c, child))
    end
    return VectorLiteral(v)
end

function to_oneline(exp::HOPPLLiteral)::String
    return sprint(show, exp)
end

function to_oneline(exp::Variable)::String
    return sprint(show, exp)
end

function to_oneline(exp::VectorLiteral)::String
    s = "["
    for (i, elem) in enumerate(exp.v)
        s *= to_oneline(elem)
        if i < length(exp.v)
            s *= " "
        else
            s *= "]"
        end
    end
    return s
end
