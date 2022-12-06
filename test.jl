using Random
using Statistics
include("hoppl/hoppl.jl")

s = """(let [z (sample 'z' (bernoulli 0.5))
mu (if (= z 0) -1.0 1.0)
d (normal mu 1.0)
y 0.5] 
(observe 'y' d y)
z)
""";


program = compile_hoppl_program(s)

include("evaluator/linearize.jl")
include("distributions/distributions.jl")
include("evaluator/evaluate.jl")

linear_program = LinearHOPPLProgram(program)

e = Evaluator(linear_program, ForwardSampler());
reset!(e); evaluate(e)


geometric = """
(defn geometric [p i]
    (let [b (sample 'b' (bernoulli p))]
        (if b i (geometric p (+ i 1)))
    )
)
(geometric 0.2 0)
""";


program = compile_hoppl_program(geometric)
linear_program = LinearHOPPLProgram(program)


e = Evaluator(linear_program, ForwardSampler());
reset!(e); Random.seed!(4); evaluate(e)


r = infer(program, ForwardSampler(), 1000)
r = to_julia.(r)
mean(r)
(1 - 0.2) / 0.2

infer_geometric = """
(defn geometric [p i]
    (let [b (sample 'b' (bernoulli p))]
        (if b i (geometric p (+ i 1)))
    )
)
(defn observe-geom [n v p ys]
    (let [y (get ys n)] 
        (observe (+ 'y' n) (geometric p 0) y)
        0
    )
)
(let [
    ys [9 0 0 6 1 4 2 1 1 0]
    p (sample 'p' (beta 1.0 1.0))
]
(loop 10 0 observe-geom p ys)
p
)

""";

ys = [9, 0, 0, 6, 1, 4, 2, 1, 1, 0]

program = compile_hoppl_program(infer_geometric)

r = infer(program, ForwardSampler(), 10)


fib = """
(defn fib [n]
    (if (<= n 2) 1 
        (+
            (fib (- n 1))
            (fib (- n 2))
        )
    )
)
(fib 10)
""";

program = compile_hoppl_program(fib)
linear_program = LinearHOPPLProgram(program)
e = Evaluator(linear_program, ForwardSampler());
reset!(e); evaluate(e)


infer(program, ForwardSampler(), 10)

#=
(let [
    x 1
    f (fn [y] (+ x y)) # LambdaLiteral which has scope info and lineinfo
]
(f 2)
)
=#