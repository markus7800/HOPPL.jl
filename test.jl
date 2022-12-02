using Random
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
(geometric 0.5 0)
""";


program = compile_hoppl_program(geometric)
linear_program = LinearHOPPLProgram(program)


e = Evaluator(linear_program, ForwardSampler());
reset!(e); Random.seed!(4); evaluate(e)


#=
geometric Variable[p, i]:
LinearHOPPL
1. CALL bernoulli: p 
2. BIND 0x0003
3. SAMPLE 0x0003 at 'b'
4. UNBIND 0x0003
5. BIND b
6. BRANCH b: 7 - 9
7. VARIABLE i
8. ENDBRANCH 14
9. CALL +: i 1 
10. BIND 0x0004
11. CALL geometric: p 0x0004 
12. UNBIND 0x0004
13. ENDBRANCH 14
14. UNBIND b
=#

# todo fibonacci