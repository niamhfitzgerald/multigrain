# DOC17b: integer weights are refused although hyp_weight is documented as numeric
# Run: Rscript DOC17b.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8), nsim = 500)
G <- matrix(c(0, 1, 1, 0), 2)

cat("hyp_weight = c(1, 0):  ", calc_power_pvals(pvals, c(1, 0), G)$local_power, "\n")
int <- tryCatch(calc_power_pvals(pvals, c(1L, 0L), G)$local_power,
                error = function(e) conditionMessage(e))
cat("hyp_weight = c(1L, 0L):", int, "\n")
cat("is_graph_valid(c(1L, 0L), G):", is_graph_valid(c(1L, 0L), G), "\n")
cat("EXPECTED: the same local power from both calls\n")
