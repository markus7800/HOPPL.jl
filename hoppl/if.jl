#=
If statements have form (if e1 e2 e3) where e1 is an
expression evaluating to a boolean b, and e2 and e3 are expressions
that are expression that are evaluated depending on the value of b.
=#

struct IfStatement <: HOPPLExpression
    condition::HOPPLExpression
    holds::HOPPLExpression
    otherwise::HOPPLExpression
end

Base.:(==)(l::IfStatement, r::IfStatement) = (l.condition == r.condition) && (l.holds == r.holds) && (l.otherwise == r.otherwise)

function print_exp(io::IO, exp::IfStatement, tab::String="")
    println(io, tab, "If")
    print_exp(io, exp.condition, tab*"  ")
    println(io)
    println(io, tab, "Then")
    print_exp(io, exp.holds, tab*"  ")
    println(io)
    println(io, tab, "Else")
    print_exp(io, exp.otherwise, tab*"  ")
end

function to_oneline(exp::IfStatement)::String
    s = "(if "
    s *= to_oneline(exp.condition)
    s *= " "
    s *= to_oneline(exp.holds)
    s *= " "
    s *= to_oneline(exp.otherwise)
    s *= ")"
    return s
end

function compile_if(c::Compiler, children::ParserChildren)::IfStatement
    if length(children) == 3
        return IfStatement(
            compile_hoppl(c, children[1]),
            compile_hoppl(c, children[2]),
            compile_hoppl(c, children[3])
        )
    else
        error("Invalid number of arguments in if statement.")
    end
end