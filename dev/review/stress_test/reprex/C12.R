# C12: control_global() can replace the objective the optimiser maximises
# Run: Rscript C12.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")   # cannot exceed 3

ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
ctrl <- control_global(ctrl, fitness = function(x) 42)     # a GA::ga() argument

msg <- tryCatch({
    set.seed(2)
    res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")
    paste("accepted; best value found by the global search:", res$global_output@fitnessValue)
}, error = function(e) conditionMessage(e))
cat("control_global(fitness = function(x) 42):", msg, "\n")
cat("EXPECTED: an error, since the objective is not a user option\n")
