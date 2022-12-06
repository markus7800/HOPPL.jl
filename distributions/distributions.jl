import Distributions

abstract type Distribution end

mutable struct Bernoulli <: Distribution
    p::Float64
end

function Bernoulli(args::Vector{T}) where T <: HOPPLExpression
    @assert length(args) == 1 "Invalid number of arguments in Bernoulli. $args"
    @assert args[1] isa FloatLiteral "Invalid argument in Bernoulli. $(args[1]) $(typeof(args[1]))" 
    return Bernoulli(args[1].f)
end

function sample(d::Bernoulli)::IntLiteral
    return IntLiteral(rand() < d.p)
end

function logprob(d::Bernoulli, x::IntLiteral)::Float64
    return x.i == 1 ? log(d.p) : log(1 - d.p)
end

function ∇logprob!(d::Bernoulli, x::IntLiteral, ∇::AbstractVector{Float64})
    ∇[1] = x.i == 1 ? 1/d.p : -1/(1-d.p)
end

function update!(d::Bernoulli, ∇::AbstractVector{Float64})
    d.p += ∇[1]
end

function n_param(d::Bernoulli)::Int
    return 1
end


mutable struct Normal <: Distribution
    μ::Float64
    σ::Float64
end

function Normal(args::Vector{T}) where T <: HOPPLExpression
    @assert length(args) == 2 "Invalid number of arguments in Normal." args
    @assert args[1] isa FloatLiteral "Invalid argument in Normal." args
    @assert args[2] isa FloatLiteral "Invalid argument in Normal." args
    return Normal(args[1].f, args[2].f)
end

function sample(d::Normal)::FloatLiteral
    z = sqrt(-2 * log(rand())) * cos(2*π*rand())
    return FloatLiteral(d.σ * z + d.μ)
end

function logprob(d::Normal, x::FloatLiteral)::Float64
    return -1/2 * ((x.f - d.μ) / d.σ)^2 - log(d.σ * sqrt(2*π))
end

function ∇logprob!(d::Normal, x::FloatLiteral, ∇::AbstractVector{Float64})
    ∇[1] = (x.f - d.μ) / d.σ^2 # ∇μ
    ∇[2] = (x.f - d.μ)^2 / d.σ^3 - 1/d.σ # ∇σ
end

function update!(d::Normal, ∇::AbstractVector{Float64})
    d.μ += ∇[1]
    d.σ += ∇[2]
    d.σ = max(d.σ, 1e-5)
end

function n_param(d::Normal)::Int
    return 2
end


mutable struct Beta <: Distribution
    α::Float64
    β::Float64
end

function Beta(args::Vector{T}) where T <: HOPPLExpression
    @assert length(args) == 2 "Invalid number of arguments in Beta." args
    @assert args[1] isa FloatLiteral "Invalid argument in Beta." args
    @assert args[2] isa FloatLiteral "Invalid argument in Beta." args
    return Beta(args[1].f, args[2].f)
end

function sample(d::Beta)::FloatLiteral
    return FloatLiteral(rand(Distributions.Beta(d.α, d.β)))
end

function logprob(d::Beta, x::FloatLiteral)::Float64
    return Distributions.logpdf(Distributions.Beta(d.α, d.β), x.f)
end

function ∇logprob!(d::Beta, x::FloatLiteral, ∇::AbstractVector{Float64})
    error("Not implemented!")
end

function update!(d::Beta, ∇::AbstractVector{Float64})
    d.α += ∇[1]
    d.α = max(d.α, 1e-5)
    d.β += ∇[2]
    d.β = max(d.β, 1e-5)
end

function n_param(d::Beta)::Int
    return 2
end

function dist_from(name::String, args::Vector{T})::Distribution where T <: HOPPLExpression
    if name == "bernoulli"
        return Bernoulli(args)
    elseif name == "normal"
        return Normal(args)
    elseif name == "beta"
        return Beta(args)
    else
        error("Unkown distribution $name.")
    end
end



function dist_from_funccall(s::FunctionCall)::Distribution
    @assert s.head isa Variable
    return dist_from(s.head.name, s.args)
end


# resolve if statements before, remove redundant x~Variable
function sample(s::FunctionCall)::HOPPLExpression
    return sample(from_funccall(s))
end

function logprob(s::FunctionCall, x::HOPPLExpression)::Float64
    return logprob(from_funccall(s), x)
end
