# C11: options of the local search are not checked; a misspelt one is dropped in silence
# Run: Rscript C11.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
con <- graph_constraint_free(3)

# 1. `max_eval` typed for the nloptr option `maxeval`: the user believes the budget is 10
ctrl <- control_local(multigrain_control(), max_eval = 10)
msg <- tryCatch({
    res <- graph_optimise(P, con, gain, global_search = FALSE, control = ctrl, verbose = "silent")
    paste("no error, no warning; evaluations used:", res$local_output$iterations)
}, error = function(e) conditionMessage(e))
cat("control_local(max_eval = 10):", msg, "\n")

# 2. a budget of 0 evaluations
ctrl <- control_local(multigrain_control(), maxeval = 0)
msg <- tryCatch({
    res <- graph_optimise(P, con, gain, global_search = FALSE, control = ctrl, verbose = "silent")
    paste("no error, no warning; evaluations used:", res$local_output$iterations)
}, error = function(e) conditionMessage(e))
cat("control_local(maxeval = 0):", msg, "\n")
cat("EXPECTED: an error for the unknown name `max_eval`, and for a `maxeval` below 1\n")
