# HS7: a short-circuited member of a shared parameter is labelled with the start value
# Run: Rscript HS7.R   (about 15 s; needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
info <- rbind(c(0.5, 1), c(NA, 1))          # H2 has one look, at full information
set.seed(1)
raw  <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = diag(2), info_frac = info, nsim = 2000)
tag  <- sf_hsd_opt(id = "shared", bounds = c(-4, 1), step = 0.5)
spec <- transform_pvalues_gsd(raw, spending = list(tag, tag), grid_size = 64L)
gain <- trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75))
set.seed(3)
res <- graph_optimise_gsd(pvals = spec, graph_constraint = graph_constraint_free(2), trial_success = gain, num_threads = 2)
cat("chosen value of the shared parameter:", res$spending_param, "\n")
cat("labels:", paste(res$spending, collapse = " | "), "\n")
cat(grep("H2:", capture.output(print(res)), value = TRUE), sep = "\n")
cat("EXPECTED: H2 labelled as having no spending choice (any value), not with the start value -1.5\n")
