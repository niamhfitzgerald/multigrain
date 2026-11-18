# fmt: skip file
# B2 on split-merge: the B2 script with seeds 1 to 20 for the search; does a returned global solution keep the fixed edge?
suppressMessages(library(multigrain))
set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7, 0.6), nsim = 4000)
gain <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")
tc <- matrix(NA_real_, 4, 4); diag(tc) <- 0; tc[1, 4] <- 1e-4
con <- graph_constraint(trans_constraint = tc)
ctrl <- control_nsim_local(control_global(multigrain_control(), popSize = 40, maxiter = 30, run = 10), 300)
res <- t(vapply(1:20, function(s) { set.seed(s); r <- graph_optimise(P, con, gain, control = ctrl, verbose = "silent")
    c(seed = s, global = r$solution$opt_source == "global", g14 = r$trans_matrix[1, 4]) }, numeric(3)))
cat("seeds whose global solution was returned:", sum(res[, "global"]), "of 20\n")
cat("G[1, 4] returned with a global solution:", unique(res[res[, "global"] == 1, "g14"]), "\n")
cat("G[1, 4] returned with a local solution: ", unique(res[res[, "global"] == 0, "g14"]), "\n")
cat("EXPECTED: G[1, 4] = 1e-04 in every run\n")
