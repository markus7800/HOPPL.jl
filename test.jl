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

l = LinearHOPPL(GenSym())
linearize(deepcopy(program.main), l)