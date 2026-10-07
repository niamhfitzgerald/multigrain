# A1: a gain that is negative for every graph is not optimised
# Run: Rscript A1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.05, 0.05, 0.90), nsim = 2000)   # only H3 has power
gain <- trial_success(0 * r1 + 0 * r2 + r3 - 2, verbose = "silent")

G <- matrix(0.5, 3, 3)
diag(G) <- 0
value <- function(w) calc_power_pvals(P, w, G, custom_power = list(g = gain))$g
cat("gain of the default start graph, weights 1/3 1/3 1/3:", value(rep(1, 3) / 3), "\n")
cat("gain with all alpha on H3,       weights 0 0 1      :", value(c(0, 0, 1)), "\n")

ctrl <- control_global(multigrain_control(), popSize = 60, maxiter = 50, run = 20)
set.seed(2)
res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")
cat("graph_optimise() returns weights", round(unname(res$hyp_weight), 3),
    "with gain", res$power$trial_success, "\n")

# The reason: the score the search sees for a point just outside the feasible region
obj <- multigrain:::create_obj_func(3, gain$func, rep(NA_real_, 3), `diag<-`(matrix(NA_real_, 3, 3), 0), P)
cat("objective at free weights (1, 1e-7), which make the third weight -1e-7:",
    obj(c(1, 1e-7, 0.5, 0.5, 0.5)), "\n")
cat("EXPECTED: weights 0 0 1 with gain -1.113, and an infeasible point scored below every graph\n")
