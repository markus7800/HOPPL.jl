# Implementations of basic operations on HOPPL literals

add(l::IntLiteral, r::IntLiteral)::IntLiteral = IntLiteral(l.i + r.i)
add(l::IntLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.i + r.f)
add(l::FloatLiteral, r::IntLiteral)::FloatLiteral = add(r, l)
add(l::FloatLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.f + r.f)

add(l::StringLiteral, r::IntLiteral)::StringLiteral = StringLiteral(l.s * string(r.i))

minus(l::IntLiteral, r::IntLiteral)::IntLiteral = IntLiteral(l.i - r.i)
minus(l::IntLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.i - r.f)
minus(l::FloatLiteral, r::IntLiteral)::FloatLiteral = FloatLiteral(l.f - r.i)
minus(l::FloatLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.f - r.f)

minus(l::IntLiteral)::IntLiteral = IntLiteral(-l.i)
minus(l::FloatLiteral)::FloatLiteral = FloatLiteral(-l.f)

mul(l::IntLiteral, r::IntLiteral)::IntLiteral = IntLiteral(l.i * r.i)
mul(l::IntLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.i * r.f)
mul(l::FloatLiteral, r::IntLiteral)::FloatLiteral = add(r, l)
mul(l::FloatLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.f * r.f)

divide(l::IntLiteral, r::IntLiteral)::IntLiteral = IntLiteral(l.i ÷ r.i)
divide(l::IntLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.i / r.f)
divide(l::FloatLiteral, r::IntLiteral)::FloatLiteral = FloatLiteral(l.f / r.i)
divide(l::FloatLiteral, r::FloatLiteral)::FloatLiteral = FloatLiteral(l.f / r.f)

and(l::BoolLiteral, r::BoolLiteral) = BoolLiteral(l.b && r.b)
and(l::BoolLiteral, r::HOPPLExpression) = l.b ? r : BoolLiteral(false)
and(l::HOPPLExpression, r::BoolLiteral) = and(r, l)

not(b::BoolLiteral) = BoolLiteral(!b.b)
function not(exp::FunctionCall)::FunctionCall
    if exp.head == Variable("=")
        return FunctionCall(Variable("!="), exp.args)
    end
    if exp.head == Variable("!=")
        return FunctionCall(Variable("=="), exp.args)
    end
    return FunctionCall(Variable("not"), [exp])
end


or(l::BoolLiteral, r::BoolLiteral) = BoolLiteral(l.b || r.b)
or(l::BoolLiteral, r::HOPPLExpression) = l.b ? l : r
or(l::HOPPLExpression, r::BoolLiteral) = or(r, l)

equals(l::IntLiteral, r::IntLiteral) = BoolLiteral(l.i == r.i)
equals(l::FloatLiteral, r::FloatLiteral) = BoolLiteral(l.f == r.f)
equals(l::IntLiteral, r::FloatLiteral) = BoolLiteral(l.i == r.f)
equals(l::FloatLiteral, r::IntLiteral) = equals(r, l)
equals(l::Variable, r::Variable) = BoolLiteral(l.name == r.name)

notequals(l::HOPPLLiteral, r::HOPPLLiteral) = not(equals(l, r))

lessthan(l::IntLiteral, r::IntLiteral) = BoolLiteral(l.i < r.i)
lessthan(l::FloatLiteral, r::FloatLiteral) = BoolLiteral(l.f < r.f)
lessthan(l::IntLiteral, r::FloatLiteral) = BoolLiteral(l.i < r.f)
lessthan(l::FloatLiteral, r::IntLiteral) = BoolLiteral(l.f < r.i)

lesseqthan(l::IntLiteral, r::IntLiteral) = BoolLiteral(l.i <= r.i)
lesseqthan(l::FloatLiteral, r::FloatLiteral) = BoolLiteral(l.f <= r.f)
lesseqthan(l::IntLiteral, r::FloatLiteral) = BoolLiteral(l.i <= r.f)
lesseqthan(l::FloatLiteral, r::IntLiteral) = BoolLiteral(l.f <= r.i)

greaterthan(l::HOPPLLiteral, r::HOPPLLiteral) = not(lesseqthan(r, l))
greatereqthan(l::HOPPLLiteral, r::HOPPLLiteral) = not(lessthan(r, l))

vecget(v::VectorLiteral, i::IntLiteral) = v.v[i.i]

const PROC2FUNC = Dict{String, Function}(
    "+" => add,
    "-" => minus,
    "*" => mul,
    "/" => divide,
    "=" => equals,
    "!=" => notequals,
    "and" => and,
    "not" => not,
    "or" => or,
    "get" => vecget,
    "<" => lessthan,
    "<=" => lesseqthan,
    ">" => greaterthan,
    ">=" => greatereqthan,
)

# and(BoolLiteral(true), Variable("v"))
# and(BoolLiteral(false), Variable("v"))

# or(BoolLiteral(true), Variable("v"))
# or(BoolLiteral(false), Variable("v"))