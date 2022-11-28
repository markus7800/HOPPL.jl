#=
A loop statement has form (loop n init f e_1 e_2 ... e_n)
where n is an integer indicating the number of iterations
f is an expression that should evaluate to a function with at least
two arguments. The iteration counter is the first argument and
init is the initial value of the second argument of f 
and e_1 to e_n are the remaining variables such that a loop
is transformed to a let block before desugaring
(let [
   a_1 e_1
   ...
   a_n e_n
   v_1 (f 1 init a_1 ... a_n)
   ...
   v_i (f n v_{n-1} a_1 ... a_n)
  ] v_n)
=#

struct LoopStatement <: HOPPLExpression
    n::Int
    init::HOPPLExpression
    body::HOPPLExpression # has to evaluate to function
    args::Vector{HOPPLExpression}
end

Base.:(==)(l::LoopStatement, r::LoopStatement) = (l.n == r.n) && (l.init == r.init) && (l.body == r.body) && all(l.args .== r.args)

function print_exp(io::IO, exp::LoopStatement, tab::String="")
    println(io, tab, "Loop ", exp.n)
    print_exp(io, exp.body, tab*"  ")
    println(io)
    print_exp(io, exp.init, tab*"  ")
    println(io)
    println(io, tab, "[")
    for (i, arg) in enumerate(exp.args)
        print_exp(io, arg, tab*"  ")
        println(io)
    end
    print(io, tab, "]")
end

function compile_loop(c::Compiler, children::ParserChildren)::LoopStatement
    @assert length(children) > 2
    @assert children[1] isa String
    n = parse(Int, children[1])
    init = compile_hoppl(c, children[2])
    body = compile_hoppl(c, children[3])
    return LoopStatement(n, init, body, HOPPLExpression[compile_hoppl(c, child) for child in children[4:end]])
end

function desugar(loop::LoopStatement)::HOPPLExpression
    args = Vector{Pair{Variable, HOPPLExpression}}()
    vars = Vector{HOPPLExpression}()
    for (i, e) in enumerate(loop.args)
        v = Variable("loop_a_$i")
        push!(args, v => e)
        push!(vars, v)
    end
    v = loop.init
    for i in 1:loop.n
        i_vars = HOPPLExpression[IntLiteral(i), v]
        push!(args, Variable("loop_v_$i") => FunctionCall(loop.body, vcat(i_vars, vars)))
        v = Variable("loop_v_$i")
    end
    return desugar(LetBlock(args, [v]))
end

loop_helper_code = """defn loop-helper [i c v g]
  (if (= i c)
    v
    (let [vn (g i v)]
      (loop-helper (+ i 1) c vn g)
    )  
  )
"""
