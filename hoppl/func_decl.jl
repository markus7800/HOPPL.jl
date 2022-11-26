#=
Function declarations are of form (defn c [a_1 a_2 ... a_n] e)
where c is the user-defined name a_1 to a_n are argument names and
e is the function body expression containing the variables a_1 to a_n.
=#

struct FunctionDeclaration <: HOPPLExpression
    name::String
    args::Vector{Variable}
    body::HOPPLExpression
    function FunctionDeclaration(name::String, args::Vector{Variable}, body::HOPPLExpression)
        @assert !(name in PRIMITIVES)
        return new(name, args, body)
    end
end

Base.:(==)(l::FunctionDeclaration, r::FunctionDeclaration) = (l.name == r.name) && all(l.args .== r.args) && (l.body == r.body)

function print_exp(io::IO, exp::FunctionDeclaration, tab::String="")
    println(io, tab, "FunctionDeclaration ", exp.name)
    print(io, tab, "[")
    for (i, arg) in enumerate(exp.args)
        print(io, arg.name)
        if i < length(exp.args)
            print(io, " ")
        end
    end
    println(io, "]")
    print_exp(io, exp.body, tab*"  ")
end

function compile_funcdef(c::Compiler, children::ParserChildren)::FunctionDeclaration
    @assert length(children) == 3
    head = children[1]
    @assert head isa String
    args_node = children[2]
    @assert args_node.children[1] == "[" args_node.children
    @assert args_node.children[end] == "]" args_node.children

    args = Vector{Variable}()
    for child in args_node.children[2:end-1]
        @assert child isa String
        push!(args, Variable(child))
    end

    body = children[3]
    return FunctionDeclaration(head, args, compile_hoppl(c, body))
end



struct InlineFunction <: HOPPLExpression
    args::Vector{Variable}
    body::HOPPLExpression
    function InlineFunction(args::Vector{Variable}, body::HOPPLExpression)
        return new(args, body)
    end
end

Base.:(==)(l::InlineFunction, r::InlineFunction) = all(l.args .== r.args) && (l.body == r.body)

function print_exp(io::IO, exp::InlineFunction, tab::String="")
    println(io, tab, "fn ", exp.name)
    print(io, tab, "[")
    for (i, arg) in enumerate(exp.args)
        print(io, arg.name)
        if i < length(exp.args)
            print(io, " ")
        end
    end
    println(io, "]")
    print_exp(io, exp.body, tab*"  ")
end

function compile_inlinefunc(c::Compiler, children::ParserChildren)::InlineFunction
    @assert length(children) == 2
    args_node = children[1]
    @assert args_node.children[1] == "[" args_node.children
    @assert args_node.children[end] == "]" args_node.children

    args = Vector{Variable}()
    for child in args_node.children[2:end-1]
        @assert child isa String
        push!(args, Variable(child))
    end

    body = children[2]
    return InlineFunction(args, compile_hoppl(c, body))
end