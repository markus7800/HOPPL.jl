#=
Parses a program into a tree structure.
Blocks are given by parenthesis () or brackets [].

Space-separated tuples are broken up into head and children:
(head child_1 child_2 ... child_n)

Example:
(let [z (sample (bernoulli 0.5))
      mu (if (= z 0) -1.0 1.0)
      d (normal mu 1.0)
      y 0.5] 
  (observe d y)
  z)

will be parsed to
("let", (
    "[",
    "z",
    ("sample", ("bernoulli", "0.5")),
    "mu",
    ("if", ("=", "z", "0"), "-1.0", "1.0"),
    "d",
    ("normal", ("mu", "1.0")),
    "y",
    "0.5",
    "]"
    ),
    ("observe", "d", "y"),
    "z"
)
=#

struct ParserNode
    parent::Union{ParserNode, Nothing}
    children::Vector{Union{ParserNode, String}}

    function ParserNode(parent::Union{ParserNode, Nothing}=nothing)
        this = new(parent, Union{ParserNode, String}[])
        if !isnothing(parent)
            push!(parent.children, this)
        end
        return this
    end
end

const ParserChild = Union{ParserNode, String}
const ParserChildren = Vector{ParserChild}

function print_node(io::IO, exp::ParserNode, tab="")
    for (i, child) in enumerate(exp.children)
        prefix = i == 1 ? "(" : ""
        suffix = i == length(exp.children) ? ")" : ""
        if child isa String
            println(io, tab, prefix, child, suffix)
        else
            print_node(io, child, tab*"  ")
            println(io, tab, suffix)
        end
    end
end

function Base.show(io::IO, exp::ParserNode)
    print_node(io, exp)
end

function parse_hoppl(s::String)::ParserNode
    s = replace(s, r"\s+" => ' ')

    out = ParserNode()
    current = out
    arg = ""
    n_open = 0
    n_close = 0
    for c in s
        if c in "() []"
            if arg != ""
                push!(current.children, arg)
            end
            arg = ""
        else
            arg *= c
        end

        if c in "(["
            n_open += 1
            current = ParserNode(current)
        end
        if c == '[' || c == ']'
            push!(current.children, string(c))
        end
        if c in ")]"
            n_close += 1
            current = current.parent
        end
    end
    @assert current == out (n_open, n_close)
    return out
end

