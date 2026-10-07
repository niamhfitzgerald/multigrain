# C10: start_graph is checked for type and size only
# Run: Rscript C10.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
con <- graph_constraint_free(3)
ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
G <- matrix(0.5, 3, 3)
diag(G) <- 0

# 1. One valid graph, not wrapped in a list
msg <- tryCatch({
    graph_optimise(P, con, gain, control = ctrl, verbose = "silent",
                   start_graph = list(hyp_weight = c(0.5, 0.3, 0.2), trans_matrix = G))
    "accepted"
}, error = function(e) conditionMessage(e))
cat("one graph, not wrapped in a list:", msg, "\n")

# 2. Weights that are not weights: a missing value, and a sum of 2
msg <- tryCatch({
    graph_optimise(P, con, gain, control = ctrl, verbose = "silent",
                   start_graph = list(list(hyp_weight = c(NA, 1, 1), trans_matrix = G)))
    "accepted, and the optimisation ran without a message"
}, error = function(e) conditionMessage(e))
cat("weights NA 1 1:", msg, "\n")
cat("EXPECTED: 1 accepted (or an error that shows the list shape); 2 an error naming start_graph[[1]]$hyp_weight\n")
