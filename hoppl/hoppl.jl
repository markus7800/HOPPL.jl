#=
The Compiler takes the result of the Parser
and transform the tuples to Julia structures
=#

const Address = UInt16

mutable struct GenSym
    address::Address
    function GenSym()
        return new(0)
    end
end

function next!(gs::GenSym)::Address
    gs.address += 1
    return gs.address
end

function next_var!(gs::GenSym)::Variable
    gs.address += 1
    return Variable(sprint(show, gs.address))
end

function next_str!(gs::GenSym)::String
    gs.address += 1
    return string(gs.address)
end

struct Compiler
    desugar::Bool
    function Compiler(desugar::Bool)
        return new(desugar)
    end
end

abstract type HOPPLExpression end

function Base.show(io::IO, exp::HOPPLExpression)
    print_exp(io, exp)
end

include("parse.jl")
include("primitives.jl")
include("literal.jl")
include("call.jl")
include("base.jl")
include("func_decl.jl")
include("if.jl")
include("let.jl")
include("loop.jl")
include("observe.jl")
include("sample.jl")

function compile_hoppl(c::Compiler, node::ParserNode)::HOPPLExpression
    if length(node.children) == 0
        return EmptyExpression()
    end

    head = popfirst!(node.children)
    children = node.children
    if head isa String
        if head == "let"
            l = compile_let(c, children)
            return c.desugar ? desugar(l) : l
        elseif head == "if"
            return compile_if(c, children)
        elseif head == "defn"
            return compile_funcdef(c, children)
        elseif head == "sample"
            return compile_sample(c, children)
        elseif head == "observe"
            return compile_observe(c, children)
        # elseif head == "fn"
        #     f = compile_inlinefunc(c, children)
        elseif head == "loop"
            l = compile_loop(c, children)
            return c.desugar ? desugar(l) : l
        elseif head == "["
            return compile_vector(c, children)
        else 
            return compile_funccall(c, head, children)            
        end
    else
        return compile_funccall(c, head, children)
    end
end

# Wraps user defined funtions and execution body
struct Program
    procs::Vector{FunctionDeclaration}
    main::HOPPLExpression
end

function Base.show(io::IO, p::Program)
    if length(p.procs) > 0
        println(io, "Procs:")
        for proc in p.procs
            println(io, proc)
        end
    end
    println(io, "Main:")
    println(io, p.main)
end

include("scope.jl")

# Convienience functions for compiling a HOPPL program from a string or Parser result.

function compile_hoppl_program(c::Compiler, code::String)::Program
    return compile_hoppl_program(c, parse_hoppl(code))
end

loop_helper = compile_hoppl(Compiler(true), parse_hoppl(loop_helper_code))

function compile_hoppl_program(c::Compiler, p::ParserNode)::Program
    procs = Vector{FunctionDeclaration}()
    # push!(procs, loop_helper)
    for child in p.children[1:end-1]
        proc = compile_hoppl(c, child)
        @assert proc isa FunctionDeclaration
        @assert proc.name != "main" # reserved
        push!(procs, proc)
    end
    main = compile_hoppl(c, p.children[end])
    p = Program(procs, main)
    p = scope_program(p)
    return p
end

function compile_hoppl_program(code::String)::Program
    p = compile_hoppl_program(Compiler(true), code)
    return p
end
function compile_hoppl_program(p::ParserNode)::Program
    p = compile_hoppl_program(Compiler(true), p)
    return p
end
