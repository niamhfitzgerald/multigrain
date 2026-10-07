# C8: a constraint of the wrong size is reported by base R or by the C++ kernel
# Run: Rscript C8.R   (needs the gsd-build build of multigrain)
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
cat("EXPECTED: two errors from the package that name both sizes\n")
