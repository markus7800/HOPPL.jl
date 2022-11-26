#=
Observe statements have form (observe d e)
where should evaluate to a distribution
and e is an expression for the observed value,
should evaluate to a literal.
=#

struct ObserveStatement <: HOPPLExpression
    address::StringLiteral
    dist::HOPPLExpression # should evaluate to dsitribution
    observation::HOPPLExpression
end

Base.:(==)(l::ObserveStatement, r::ObserveStatement) = (l.address == r.address) && (l.dist == r.dist) && (l.observation == r.observation)

function print_exp(io::IO, exp::ObserveStatement, tab::String="")
    println(io, tab, "Observe ", exp.address.s, " ")
    print_exp(io, exp.dist, tab*"  ")
    println(io)
    println(io, tab, "Value")
    print_exp(io, exp.observation, tab*"  ")
end

function to_oneline(exp::ObserveStatement)::String
    s = "(observe " * exp.address.s * " "
    s *= to_oneline(exp.dist)
    s *= " "
    s *= to_oneline(exp.observation)
    s *= ")"
    return s
end

function compile_observe(c::Compiler, children::ParserChildren)::ObserveStatement
    if length(children) != 3
        error("Invalid number of arguments in observe.")
    end
    return ObserveStatement(compile_hoppl(c, children[1]), compile_hoppl(c, children[2]), compile_hoppl(c, children[3]))
end