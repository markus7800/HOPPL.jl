using Random
using Statistics
import Distributions
include("hoppl/hoppl.jl")


include("distributions/distributions.jl")

include("evaluator/linearize.jl")
include("evaluator/evaluate.jl")


include("old_evaluator/evaluate.jl")
include("old_evaluator/IS.jl")


s = """(let [z (sample 'z' (bernoulli 0.5))
mu (if (= z 0) -1.0 1.0)
d (normal mu 1.0)
y 0.5] 
(observe 'y' d y)
z)
""";

s = "(let [A (sample 'A' (bernoulli 0.5))
      B (observe 'B' (bernoulli (if (= A 1) 0.2 0.8)) 0)
      C (sample 'C' (bernoulli (if (= B 1) 0.9 0.7)))]
      (observe 'D' (bernoulli (if (= C 1) 0.5 0.2)) 1)
      (+ A C)
)
";


program = compile_hoppl_program(s)
@time lp, r = infer(program, IS(1_000_000))


@time r = infer(program, ForwardSampler(), 100000)
@profview r = infer(program, ForwardSampler(), 100000)

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

@time lp, r = infer(program, IS(1_000_000))

using Profile

@profview r = infer(program, ForwardSampler(), 100000)
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
        (observe (+ 'y' n) (normal (geometric p 0.0) 0.1) y)
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

@time lp, r = infer(program, IS(1_000_000))


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