#=
sample statements have form (sample d)
where d should evaluate to a distribution
=#

struct SampleStatement <: HOPPLExpression
    address::StringLiteral
    dist::HOPPLExpression # should evaluate to distribution
end

Base.:(==)(l::SampleStatement, r::SampleStatement) = (l.dist == r.dist)

function print_exp(io::IO, exp::SampleStatement, tab::String="")
    println(io, tab, "Sample ", exp.address.s)
    print_exp(io, exp.dist, tab*"  ")
end

function to_oneline(exp::SampleStatement)::String
    s = "(sample " * exp.address.s * " "
    s *= to_oneline(exp.dist)
    s *= ")"
    return s
end

function compile_sample(c::Compiler, children::ParserChildren)::SampleStatement
    if length(children) != 2
        error("Invalid number of arguments in sample.")
    end

    return SampleStatement(compile_hoppl(c, children[1]),  compile_hoppl(c, children[2]))
end
