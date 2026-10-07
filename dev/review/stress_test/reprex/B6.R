# B6: the returned graph can be worse than the graph the search started from
# Run: Rscript B6.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.56, 0.77, 0.61), nsim = 20000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

Gd <- matrix(0.5, 3, 3)               # the default start graph: equal weights, equal edges
diag(Gd) <- 0
start_gain <- calc_power_pvals(P, rep(1, 3) / 3, Gd, custom_power = list(g = gain))$g

ctrl <- control_nsim_local(multigrain_control(), 1000)   # local search on 1,000 of the 20,000 rows
set.seed(2)
res <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE,
                      control = ctrl, verbose = "silent")

cat("gain of the default start graph on all rows:", start_gain, "\n")
cat("gain of the returned graph on all rows     :", res$power$trial_success, "\n")
cat("returned weights:", round(unname(res$hyp_weight), 3), " source:", res$solution$opt_source, "\n")
cat("EXPECTED: a returned gain of at least", start_gain, "\n")
