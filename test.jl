using Random
using Statistics
import Distributions
include("hoppl/hoppl.jl")
include("evaluator/linearize.jl")
include("distributions/distributions.jl")
include("evaluator/evaluate.jl")

s = """(let [z (sample 'z' (bernoulli 0.5))
mu (if (= z 0) -1.0 1.0)
d (normal mu 1.0)
y 0.5] 
(observe 'y' d y)
z)
""";


program = compile_hoppl_program(s)


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


p = 0.2
Random.seed!(0)
ys = rand(Distributions.Geometric(p), 10)

posterior = Distributions.Beta(1 + length(ys), 1 + sum(ys))
mean(posterior)

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
    ys [$(join(ys, " "))]
    p (sample 'p' (beta 1.0 1.0))
]
(loop 10 0 observe-geom p ys)
p
)

""";
program = compile_hoppl_program(infer_geometric)

Random.seed!(0)
r = infer(program, ForwardSampler(), 1000)

Random.seed!(0)
r, lp = infer(program, IS(), 1000)


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