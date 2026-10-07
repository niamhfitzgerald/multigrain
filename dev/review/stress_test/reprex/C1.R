# C1 (with ST2): an analysis that spends nothing makes the whole transform abort
# Run: Rscript C1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.05, 0.5, 1)                    # a first look at 5% of the information
cat("sfLDOF cumulative spend of 0.025 at the three analyses:", sfLDOF(0.025, info)$spend, "\n")

set.seed(1)
raw <- simulate_pvalues_gsd(0.9, info_frac = info, nsim = 1000)
pv <- tryCatch(
    transform_pvalues_gsd(raw, spending = sfLDOF, grid_size = 4096),   # 4 times the default
    error = function(e) conditionMessage(e)
)
if (is.character(pv)) {
    cat("transform_pvalues_gsd() stops with:\n", pv, "\n")
} else {
    cat("repeated p-values at analysis 1, range:", range(pv$pvals[, 1, 1]), "\n")
    cat("share below 0.025 at analyses 2 and 3:", colMeans(pv$pvals[, 1, 2:3] < 0.025), "\n")
}
cat("EXPECTED: repeated p-values of 1 at analysis 1 (it cannot reject);",
    "analyses 2 and 3 transformed\n")
