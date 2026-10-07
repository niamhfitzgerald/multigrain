# A5: an information fraction above 1 with an uncapped spending function spends more than alpha
# Run: Rscript A5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

lin <- function(alpha, t) alpha * t        # hand-written linear spending
info <- c(0.5, 1.2)                        # the final analysis over-runs by 20%
cat("spend of 0.025 at t = 1, the only point the package checks:", lin(0.025, 1), "\n")
cat("cumulative spend of 0.025 at the two analyses:", lin(0.025, info), "\n")

set.seed(1)
raw <- simulate_pvalues_gsd(0.025, info_frac = info, nsim = 2e5)   # one true null hypothesis
pv <- transform_pvalues_gsd(raw, spending = lin, alpha = 0.025)
tab <- pv$tables[[1]]
cat("nominal boundaries at the full level:", signif(tab$bounds[nrow(tab$bounds), ], 4), "\n")

out <- calc_power_pvals_gsd(pv, 1, matrix(0, 1, 1), sum_to_one_constraint = FALSE)
cat("type I error at one-sided alpha 0.025:", out$local_power, "\n")
cat("EXPECTED: an error, since the function spends 0.030 of a level of 0.025;",
    "never a type I error above 0.025\n")
