# HS1: when the genetic algorithm's graph is kept, print() and summary() describe the local search's design
# Run: Rscript HS1.R   (about 20 s; needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
corr <- matrix(c(1, 0.5, 0.5, 1), 2)
set.seed(1)
raw  <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = corr, info_frac = c(0.5, 1), nsim = 5000)
spec <- transform_pvalues_gsd(raw, spending = list(gsDesign::sfLDOF, sf_hsd_opt(bounds = c(-4, 1), step = 0.5)), grid_size = 128L)
gain <- trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75))
res  <- graph_optimise_gsd(pvals = spec, graph_constraint = graph_constraint_free(2), trial_success = gain,
                           control = control_nsim_local(multigrain_control(), 300), num_threads = 2)
prof <- res$spending_profile
cat("solution source:", res$solution$opt_source, "\n")
cat("reported gamma:", res$spending_param, "\n")
cat("profile row at the reported gamma: diff =", prof$diff[prof$value == res$spending_param], "\n")
cat("profile row with diff 0 (the profile's own optimum): gamma =", prof$value[prof$diff == 0], "\n")
cat(grep("within 5e-4", capture.output(print(res)), value = TRUE), sep = "\n")
cat("EXPECTED: diff 0 at the reported gamma, or a note that the profile and its plateaus come from another design\n")
