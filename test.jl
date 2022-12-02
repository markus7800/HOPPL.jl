include("hoppl/hoppl.jl")

s = """(let [z (sample 'z' (bernoulli 0.5))
mu (if (= z 0) -1.0 1.0)
d (normal mu 1.0)
y 0.5] 
(observe 'y' d y)
z)
"""


program = compile_hoppl_program(s)

include("evaluator/linearize.jl")
include("distributions/distributions.jl")
include("evaluator/evaluate.jl")

linear_program = LinearHOPPLProgram(program)

e = Evaluator(linear_program, ForwardSampler());
reset!(e); evaluate(e)


geometric = """
(defn geometric [p]
    (let [b (sample (bernoulli p))]
        (if b 1 (geometric p))
    )
)


"""