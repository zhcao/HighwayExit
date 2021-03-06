using GenerativeModels
using POMDPs
using POMDPToolbox
using ProfileView
using Multilane
using MCTS
using RobustMCTS

nb_lanes = 4
pp = PhysicalParam(nb_lanes,lane_length=100.) #2.=>col_length=8\n",
_discount = 1.
nb_cars = 10
rmodel = NoCrashRewardModel()
dmodel = NoCrashIDMMOBILModel(nb_cars, pp)
mdp = NoCrashMDP(dmodel, rmodel, _discount);
rng = MersenneTwister(5)


# dpws = DPWSolver(depth=20,
#                  n_iterations=500,
#                  exploration_constant=100.0,
#                  k_state=4.0,
#                  alpha_state=1/8,
#                  rollout_solver=SimpleSolver()) 
# 
# policy = solve(dpws, mdp)

# policy = RandomPolicy(mdp, rng=rng)

rsolver = RobustMCTSSolver(
    depth=20,
    c = 100.0,
    n_iterations=500,
    k_state=4.0,
    alpha_state=1/8,
    k_nature=4.0,
    alpha_nature=1/8,
    rollout_solver=SimpleSolver(),
    rollout_nature=StochasticBehaviorNoCrashMDP(mdp))


solver = RobustMLSolver(rsolver)
policy = solve(solver, mdp)


sim = RolloutSimulator(max_steps=10)

@time simulate(sim, mdp, policy, initial_state(mdp, rng))
@time for i in 1
    simulate(sim, mdp, policy, initial_state(mdp, rng))
end

Profile.clear()
@profile for i in 1
    simulate(sim, mdp, policy, initial_state(mdp, rng))
end

ProfileView.view()
