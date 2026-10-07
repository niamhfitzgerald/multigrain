# B2: a fixed constraint value below 0.001 is not kept
# Run: Rscript B2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7, 0.6), nsim = 4000)
gain <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")

tc <- matrix(NA_real_, 4, 4)
diag(tc) <- 0
tc[1, 4] <- 1e-4                      # an epsilon edge H1 -> H4, fixed by the user
con <- graph_constraint(trans_constraint = tc)

# a short global search, and a local search on 300 rows so that the global solution is returned
ctrl <- control_global(multigrain_control(), popSize = 40, maxiter = 30, run = 10)
ctrl <- control_nsim_local(ctrl, 300)

set.seed(3)
res <- graph_optimise(P, con, gain, control = ctrl, verbose = "silent")
cat("solution taken from the", res$solution$opt_source, "search\n")
cat("constraint on G[1, 4]:", con$trans_constraint[1, 4], "\n")
cat("returned G[1, 4]     :", res$trans_matrix[1, 4], "\n")
cat("EXPECTED: returned G[1, 4] equal to the fixed value 1e-04\n")
