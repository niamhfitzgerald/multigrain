# C8: a constraint of the wrong size is reported by base R or by the C++ kernel (fixed-sample functions)
# Run: Rscript C8.R   (needs a gsd-build or gsd-build-spending build of multigrain)
# fmt: skip file
library(multigrain)

# 1. Four weights with a 3 x 3 matrix. The package has a message for this, and a diagnosis.
free3 <- rbind(c(0, NA, NA), c(NA, 0, NA), c(NA, NA, 0))
msg <- tryCatch(
    graph_constraint(c(NA, NA, NA, NA), free3, diagnose = TRUE),
    error = function(e) conditionMessage(e)
)
cat("graph_constraint(4 weights, 3 x 3 matrix):", msg, "\n")

# 2. A valid constraint for 3 hypotheses, p-values and gain for 4.
set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7, 0.6), nsim = 500)
gain <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")
msg <- tryCatch(
    graph_optimise(P, graph_constraint_free(3), gain, verbose = "silent"),
    error = function(e) conditionMessage(e)
)
cat("graph_optimise(4 hypotheses, constraint for 3):", msg, "\n")

# 3. For comparison: the group sequential optimiser names both sizes.
raw <- simulate_pvalues_gsd(c(0.9, 0.8, 0.7, 0.6), info_frac = c(0.5, 1), nsim = 500)
pv <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
gain_gsd <- trial_success_gsd(r1 + r2 + r3 + r4, K = 2, verbose = "silent")
msg <- tryCatch(
    graph_optimise_gsd(pv, graph_constraint_free(3), gain_gsd, verbose = "silent"),
    error = function(e) gsub("\\s+", " ", conditionMessage(e))
)
cat("graph_optimise_gsd(4 hypotheses, constraint for 3):", msg, "\n")
cat("EXPECTED: errors from the package that name both sizes in 1 and 2, as in 3\n")
