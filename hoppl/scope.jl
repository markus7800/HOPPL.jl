#=
Renames variables if necessary to give them local scope.
Function names are also variables.
Appends ~i to variable name.
Program has to be desugared.

s = "
(defn a [a] (+ a a))
(let [b (a 3)
      c a
      a 2
      a (* a b)
      c (c a)
     ]
    c
 )
" 

will be scoped to

Procs:
FunctionDeclaration a
[a]
  Call
    +
      a
      a
Main:
Let [
b =>
  Call
    a
      3
]
  Let [
  c =>
    a
  ]
    Let [
    a~2 =>
      2
    ]
      Let [
      a~3 =>
        Call
          *
            a~2
            b
      ]
        Let [
        c~2 =>
          Call
            c
              a~3
        ]
          c~2

and evaluates to 24.
=#


# every time we encounter a let statement, we begin a new scope
function scope(v::Variable, i::Int, in_exp::Let)::Let
    if v.name == in_exp.v.name
        # begin new scope
        if i == 0
            v_new = Variable(v.name)
        else
            v_new = Variable(v.name * "~$(i+1)")
        end
        return Let(v_new, scope(v, i, in_exp.binding), scope(v, i+1, in_exp.body))
    else
        return Let(in_exp.v, scope(v, i, in_exp.binding), scope(v, i, in_exp.body))
    end
end

function scope(v::Variable, i::Int, in_exp::HOPPLLiteral)::HOPPLExpression
    return in_exp
end

function scope(v::Variable, i::Int, in_exp::Variable)::HOPPLExpression
    if in_exp.name == v.name
        if i == 1
            return Variable(v.name)
        elseif i == 0 && v.name in PRIMITIVES
            # primitives are special variabels which don't have a scope
            # variables are not allowed to be named like primitives (enforced in Let)
            # however, user defined procedures can be overwritten with local variabels
            return Variable(v.name)
        else
            return Variable(v.name * "~$i")
        end
    else
        return in_exp
    end
end

function scope(v::Variable, i::Int, in_exp::FunctionCall)::FunctionCall
    return FunctionCall(scope(v, i, in_exp.head), HOPPLExpression[scope(v, i, arg) for arg in in_exp.args])
end

function scope(v::Variable, i::Int, in_exp::IfStatement)::IfStatement
    return IfStatement(scope(v, i, in_exp.condition), scope(v, i, in_exp.holds), scope(v, i, in_exp.otherwise))
end

function scope(v::Variable, i::Int, in_exp::ObserveStatement)::ObserveStatement
    return ObserveStatement(scope(v, i, in_exp.dist), scope(v, i, in_exp.observation))
end

function scope(v::Variable, i::Int, in_exp::SampleStatement)::SampleStatement
    return SampleStatement(in_exp.address, scope(v, i, in_exp.dist))
end

function scope(v::Variable, i::Int, in_exp::VectorLiteral)::VectorLiteral
    cs = HOPPLExpression[]
    for x in in_exp.v
        push!(cs, scope(v, i, x))
    end
    return VectorLiteral(cs)
end


function collect_variables(exp::HOPPLLiteral, bound::Bool)::Vector{Variable}
    return Variable[]
end

function collect_variables(exp::Variable, bound::Bool)::Vector{Variable}
    if exp.name in PRIMITIVES || bound
        return Variable[] # bound variables are only in let statement
    else
        return Variable[exp]
    end
end

function collect_variables(exp::Let, bound::Bool)::Vector{Variable}
    vars = Variable[exp.v] # bound variables are only in let statement
    vars = vars ∪ collect_variables(exp.binding, bound)
    vars = vars ∪ collect_variables(exp.body, bound)
    return vars
end

function collect_variables(exp::IfStatement, bound::Bool)::Vector{Variable}
    vars = collect_variables(exp.condition, bound)
    vars = vars ∪ collect_variables(exp.holds, bound)
    vars = vars ∪ collect_variables(exp.otherwise, bound)
    return vars
end

function collect_variables(exp::FunctionCall, bound::Bool)::Vector{Variable}
    vars = collect_variables(exp.head, bound)
    for arg in exp.args
        vars = vars ∪ collect_variables(arg, bound)
    end
    return vars
end

function collect_variables(exp::SampleStatement, bound::Bool)::Vector{Variable}
    vars = collect_variables(exp.dist, bound)
    return vars
end

function collect_variables(exp::ObserveStatement, bound::Bool)::Vector{Variable}
    vars = collect_variables(exp.dist, bound)
    vars = vars ∪ collect_variables(exp.observation, bound)
    return vars
end

function collect_variables(exp::VectorLiteral, bound::Bool)::Vector{Variable}
    vars = Variable[]
    for x in exp.v
        vars = vars ∪ collect_variables(x, bound)
    end
    return vars
end

collet_all_variables(exp::HOPPLExpression) = collect_variables(exp, false)
collect_bound_variables(exp::HOPPLExpression) = collect_variables(exp, true)
collect_free_variables(exp::HOPPLExpression) = setdiff(collect_variables(exp, false), collect_variables(exp, true))

# exp has to be desugared
function scope_program(p::Program)::Program
    scoped_procs = Vector{FunctionDeclaration}()
    procedure_names = Set{String}()

    procedure_names = [funcdef.name for funcdef in p.procs]
    @assert length(Set(procedure_names)) == length(p.procs)

    for (i, funcdef) in enumerate(p.procs)
        @assert funcdef isa FunctionDeclaration
        @assert !(funcdef.name in PRIMITIVES)
        proc_args = funcdef.args
        body_args = collet_all_variables(funcdef.body)
        body_args = setdiff(body_args, proc_args)

        # println("proc_args: ", proc_args)
        body = funcdef.body
        for proc_arg in proc_args
            @assert !(proc_arg.name in PRIMITIVES)
            body = scope(proc_arg, 1, body)
        end
        # println("body_args: ", body_args)
        for body_arg in body_args
            @assert !(body_arg.name in procedure_names[i:end]) # forbid recursion
            @assert !(body_arg.name in PRIMITIVES)
            body = scope(body_arg, 0, body)
        end
        push!(scoped_procs, FunctionDeclaration(funcdef.name, funcdef.args, body))
    end
    # println("procedure_names: ", procedure_names)

    main = p.main
    vars = collet_all_variables(main)
    for v in vars
        @assert !(v.name in PRIMITIVES) # redundant
        if v.name in procedure_names
            main = scope(v, 1, main)
        else
            main = scope(v, 0, main)
        end
    end

    return Program(scoped_procs, main, p.n_vars)
end
