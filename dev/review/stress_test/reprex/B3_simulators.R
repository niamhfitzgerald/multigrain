# B3 (simulators) and DOC17e: power_nominal and nsim are not validated by the simulators
# Run: Rscript B3_simulators.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

msg <- tryCatch(simulate_pvalues(c(0.9, 0.8), nsim = 0), error = function(e) conditionMessage(e))
cat("simulate_pvalues(nsim = 0) says:", msg, "\n")

set.seed(1)
P <- simulate_pvalues(c(0.9, 80, 0.7), nsim = 2000)          # 80 typed for 0.80
cat("NaN in each column of the simulated p-values:", colSums(is.nan(P)), "\n")
cat("EXPECTED: an error that names nsim, and an error that names the second",
    "element of power_nominal\n")
