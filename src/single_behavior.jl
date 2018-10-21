# Code for solving assuming that all other cars have a single identical behavior model

type SingleBehaviorSolver <: Solver
    inner_solver::Solver
    behavior::BehaviorModel
end

abstract type Policy{MLState} end
struct SingleBehaviorPolicy{Policy,BehaviorModel} #<: Policy{MLState}
    inner_policy::Policy
    behavior::BehaviorModel
end

#
#type SingleBehaviorPolicy <: Policy{MLState}
#    inner_policy::Policy{MLState}
#    behavior::BehaviorModel
#end


set_rng!(solver::SingleBehaviorSolver, rng::AbstractRNG) = set_rng!(solver.inner_solver, rng)

function solve(solver::SingleBehaviorSolver, mdp::NoCrashProblem)
    single_behavior_mdp = deepcopy(mdp)
    single_behavior_mdp.dmodel.behaviors = DiscreteBehaviorSet(BehaviorModel[solver.behavior], Weights([1.0]))

    inner_policy = solve(solver.inner_solver, single_behavior_mdp)
    return SingleBehaviorPolicy(inner_policy, solver.behavior)
end

function action(p::SingleBehaviorPolicy, s::MLState, a::MLAction=MLAction())
    as = actions(p.inner_policy.mdp, s, actions(p.inner_policy.mdp))
    if length(as) == 1
        return first(as)
    end
    return action(p.inner_policy, single_behavior_state(s, p.behavior))
end

function single_behavior_state(s::MLState, behavior)
    new_cars = Array(CarState, length(s.cars))
    for (i,c) in enumerate(s.cars)
        new_cars[i] = CarState(c.x, c.y, c.vel, c.lane_change, behavior, c.id)
    end
    return MLState(s, new_cars)
end
