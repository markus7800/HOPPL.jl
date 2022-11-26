#=
Function call is of form (e e_1 e_2 ... e_n)
where e is a should evaluate to a function name, either user-defined or primitive
and e_1 to e_n are expressions that evaluate to the function arguments.
=#

struct FunctionCall <: HOPPLExpression
    head::HOPPLExpression
    args::Vector{HOPPLExpression}
end

Base.:(==)(l::FunctionCall, r::FunctionCall) = (l.head == r.head) && all(l.args .== r.args)

function print_exp(io::IO, exp::FunctionCall, tab::String="")
    println(io, tab, "Call")
    print_exp(io, exp.head, tab*"  ")
    for arg in exp.args
        println(io)
        print_exp(io, arg, tab*"    ")
    end
end

function to_oneline(exp::FunctionCall)::String
    s = "("
    s *= to_oneline(exp.head)
    for arg in exp.args
        s *= " "
        s *= to_oneline(arg)
    end
    s *= ")"
    return s
end

function compile_funccall(c::Compiler, head::String, children::ParserChildren)::FunctionCall
    return FunctionCall(Variable(head), HOPPLExpression[compile_hoppl(c, child) for child in children])
end

function compile_funccall(c::Compiler, head::ParserNode, children::ParserChildren)::FunctionCall
    error("First argument of call tuple has to be string.")
    #return FunctionCall(compile_hoppl(c, head), HOPPLExpression[compile_hoppl(c, child) for child in children])
end