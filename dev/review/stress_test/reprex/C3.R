# C3: a missing p-value at a single full-information analysis stays NA
# Run: Rscript C3.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

info <- rbind(c(0.5, 1), c(NA, 1))         # H2 is analysed once, at full information
set.seed(1)
raw <- array(runif(5 * 2 * 2), dim = c(5, 2, 2))
raw[1, , ] <- NA                           # one trial without p-values
pv <- transform_pvalues_gsd(raw, info_frac = info, spending = gsDesign::sfLDOF)
cat("trial 1, H1 (two analyses), repeated p-values:", pv$pvals[1, 1, ], "\n")
cat("trial 1, H2 (one analysis), repeated p-values:", pv$pvals[1, 2, ], "\n")

msg <- tryCatch(
    {
        calc_power_pvals_gsd(pv, c(0.5, 0.5), rbind(c(0, 1), c(1, 0)))
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("calc_power_pvals_gsd() on that object says:\n", msg, "\n")
cat("EXPECTED: 1 1 for both hypotheses (a missing p-value cannot reject) and no error\n")
