#!/usr/bin/julia --color=yes

using ArgParse

using JLD
using Multilane
using POMDPs
using MCTS
using DataFrames
using DataFramesMeta
using Plots

s = ArgParseSettings()

@add_arg_table s begin
    "--show", "-s"
        help = "show results; print stats and solvers"
        action = :store_true
    "--unicode", "-u"
        help = "show unicode plot"
        action = :store_true
    "--plot", "-p"
        help = "plot paretto curves"
        action = :store_true
    "--spreadsheet"
        help = "[NOT IMPLEMENTED] save stats as a csv in /tmp/ and open with xdg-open"
        action = :store_true
    "filename"
        help = "file name"
        nargs = '+' # will be + at some point
    "--solvers"
        help = "solvers to be included"
        nargs = '+'
    "--save-combined"
        help = "save results to a new file"
        action = :store_true
end

args = parse_args(ARGS, s)

results = load(args["filename"][1])

stats = results["stats"]

mean_performance = by(stats, :solver_key) do df
    by(df, :lambda) do df
        DataFrame(steps_in_lane=mean(df[:steps_in_lane]),
                  nb_brakes=mean(df[:nb_brakes]),
                  time_to_lane=mean(df[:time_to_lane]),
                  steps=mean(df[:steps]),
                  )
    end
end

solvers = args["solvers"]
if isempty(solvers)
    solvers = unique(mean_performance[:solver_key])
end

mean_performance = @where(mean_performance,
                          collect(Bool[s in solvers for s in :solver_key]))

if args["show"]
    println(mean_performance)
    println()
end

if args["unicode"] || args["plot"]
    try
        if args["unicode"]
            unicodeplots()
        else
            pyplot()
        end
        for g in groupby(mean_performance, :solver_key)
            if size(g,1) > 1
                # plot!(g, :steps_in_lane, :nb_brakes, group=:solver_key)
                plt = plot!(g, :time_to_lane, :nb_brakes, group=:solver_key)
            else
                # scatter!(g, :steps_in_lane, :nb_brakes, group=:solver_key)
                plt = scatter!(g, :time_to_lane, :nb_brakes, group=:solver_key)
            end
        end
        gui()
    catch ex
        warn("Plot could not be displayed:")
        println(ex)
    end
end