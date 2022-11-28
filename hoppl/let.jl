#=
Let blocks have form (let [a_1 b_1 a_2 b_2 ... a_n b_n] e_1 e_2 ... e_n)
where b_1 to b_n are expressions bound to the variables with names a_1 to a_n.
e_1 to e_n are expressions that are executed consecutively containing
the bound variables.
A let block will be desugared to nested Lets of form
(let [a_1 b_1] (let [a_2 b_2] (... (let [_ e_{n-1}] e_n)))))
=#

struct LetBlock <: HOPPLExpression
    args::Vector{Pair{Variable, HOPPLExpression}}
    block::Vector{HOPPLExpression}
end

Base.:(==)(l::LetBlock, r::LetBlock) = all(l.args .== r.args) && all(l.block .== r.block)

function print_exp(io::IO, exp::LetBlock, tab::String="")
    println(io, tab, "LetBlock [")
    for (k, v) in exp.args
        println(io, tab, k.name, " =>")
        print_exp(io, v, tab*"  ")
        println(io)
    end
    println(io, tab, "]")
    for e in exp.block
        print_exp(io, e, tab*"  ")
    end
end

function compile_let(c::Compiler, children::ParserChildren)::LetBlock
    bindings = Vector{ParserChild}()
    body = Vector{ParserChild}()
    @assert length(children) >= 2

    bindings = children[1].children
    @assert bindings[1] == "["
    @assert bindings[end] == "]"
    bindings = bindings[2:end-1]
    if !iseven(length(bindings))
        error("Invalid number of arguments in let.")
    end
    d = Vector{Pair{Variable, HOPPLExpression}}()
    for i in 1:2:length(bindings)
        v = bindings[i]
        e = bindings[i+1]
        @assert v isa String
        push!(d, Variable(v) => compile_hoppl(c, e))
    end

    body = children[2:end]
    body = HOPPLExpression[compile_hoppl(c, child) for child in body]
    return LetBlock(d, body)
end

# Lets are of form (let [a b] e)
# with an expression b bound to variable with name a.
# Execution is cuntinued with expression e containing a.
struct Let <: HOPPLExpression
    v::Variable
    binding::HOPPLExpression
    body::HOPPLExpression
    function Let(v::Variable, binding::HOPPLExpression, body::HOPPLExpression)
        @assert !(v.name in PRIMITIVES) # don't allow to be named like primitive
        return new(v, binding, body)
    end
end

Base.:(==)(l::Let, r::Let) = (l.v == r.v) && (l.binding == r.binding) && (l.body == r.body)

# function desugar(l::Let)::FunctionCall
#     return FunctionCall(InlineFunction(Variable[l.v], l.body), HOPPLExpression[l.binding])
# end

function desugar(letblock::LetBlock)::HOPPLExpression
    block = letblock.block
    body = block[end]
    for statement in reverse(block[1:end-1])
        body = Let(Variable("_"), statement, body)
    end

    for (v, b) in reverse(letblock.args)
        body = Let(v, b, body)
    end
    return body # if let has no bindings simply return body
end

function print_exp(io::IO, exp::Let, tab::String="")
    println(io, tab, "Let [")
    println(io, tab, exp.v.name, " =>")
    print_exp(io, exp.binding, tab*"  ")
    println(io)
    println(io, tab, "]")
    print_exp(io, exp.body, tab*"  ")
end

function to_oneline(exp::Let)::String
    s = "(let ["
    s *= to_oneline(exp.v)
    s *= " "
    s *= to_oneline(exp.binding)
    s *= "] "
    s *= to_oneline(exp.body)
    s *= ")"
    return s
end