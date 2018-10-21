#=
type RobustNoCrashMDP <: RobustMDP{MLPhysicalState, MLAction}
    base::MLMDP
end
RobustMCTS.representative_mdp(rmdp::RobustNoCrashMDP) = StochasticBehaviorNoCrashMDP(rmdp.base)

function RobustMCTS.next_model(gen::RandomModelGenerator, rmdp::RobustNoCrashMDP, s::MLPhysicalState, a::MLAction)
    behaviors = Dict{Int, Nullable{BehaviorModel}}(1=>nothing)
    for c in s.cars
        # TODO instead of just using sample, try to pick models that will be bad
        behaviors[c.id] = rand(gen.rng, rmdp.base.dmodel.behaviors)
    end
    return FixedBehaviorNoCrashMDP(behaviors, rmdp.base)
end
=#

abstract type EmbeddedBehaviorMDP <: MDP{MLPhysicalState, MLAction} end

actions(p::EmbeddedBehaviorMDP) = actions(p.base)
actions(p::EmbeddedBehaviorMDP, s::MLPhysicalState, as::NoCrashActionSpace) = actions(p.base, s, as)
create_action(p::EmbeddedBehaviorMDP) = create_action(p.base)
create_state(p::EmbeddedBehaviorMDP) = MLPhysicalState(false, 0.0, 0.0, [])
discount(p::EmbeddedBehaviorMDP) = discount(p.base)
# reward(p::EmbeddedBehaviorMDP, s::MLPhysicalState, a::MLAction, sp::MLPhysicalState)

struct FixedBehaviorNoCrashMDP <: EmbeddedBehaviorMDP
    behaviors::Dict{Int,Nullable{BehaviorModel}}
    base::MLMDP
end

import POMDPs.generate_s
import POMDPs.generate_sr

function generate_sr(mdp::MDP, s::MLState, a::MLAction, rng::AbstractRNG, sp::MLState=create_state(mdp))
    full_s = MLState(s, Array{CarState}(length(s.cars)))
    for i in 1:length(s.cars)
        full_s.cars[i] = CarState(CarPhysicalState(s.cars[i]), rand(rng, mdp.dmodel.behaviors))
    end

    full_sp = generate_s(mdp, full_s, a, rng)
    return full_sp, reward(mdp, full_s, a, full_sp)
end



function generate_sr(mdp::FixedBehaviorNoCrashMDP, s::MLPhysicalState, a::MLAction, rng::AbstractRNG, sp::MLPhysicalState=create_state(mdp))
    print("111")
#=
    full_s = MLState(s, Array(CarState, length(s.cars)))
    for (i,c) in enumerate(s.cars)
        full_s.cars[i] = CarState(c, mdp.behaviors[c.id])
    end
    full_sp = generate_s(mdp.base, full_s, a, rng)
    for c in sp.cars
        if !haskey(mdp.behaviors, c.id)
            mdp.behaviors[c.id] = c.behavior
        end
    end
    return MLPhysicalState(full_sp), reward(mdp.base, full_s, a, full_sp)

=#
end

struct StochasticBehaviorNoCrashMDP <: EmbeddedBehaviorMDP
    base::MLMDP
end

function generate_sr(mdp::StochasticBehaviorNoCrashMDP, s::MLPhysicalState, a::MLAction, rng::AbstractRNG, sp::MLPhysicalState=create_state(mdp))
    print("222")
#=
    full_s = MLState(s, Array(CarState, length(s.cars)))
    for i in 1:length(s.cars)
        full_s.cars[i] = CarState(s.cars[i], rand(rng, mdp.base.dmodel.behaviors))
    end
    full_sp = generate_s(mdp.base, full_s, a, rng)
    return MLPhysicalState(full_sp), reward(mdp.base, full_s, a, full_sp)
=#
end

function initial_state(mdp::Union{FixedBehaviorNoCrashMDP,StochasticBehaviorNoCrashMDP}, rng::AbstractRNG, s=nothing)
    full_state = initial_state(mdp.base, rng::AbstractRNG)
    return MLPhysicalState(full_state)
end

#=
type RobustMLSolver <: Solver
    rsolver
end

type RobustMLPolicy <: Policy{MLState}
    rpolicy
end

function action(p::RobustMLPolicy, s::MLState, a::MLAction=MLAction(0,0))
    mdp = representative_mdp(p.rpolicy.rmdp)
    as = actions(mdp, MLPhysicalState(s), actions(mdp))
    if length(as) == 1
        return collect(as)[1]
    end
    action(p.rpolicy, MLPhysicalState(s))
end

function solve(s::RobustMLSolver, mdp::MLMDP)
    RobustMLPolicy(solve(s.rsolver, RobustNoCrashMDP(mdp::MLMDP)))
end
=#
