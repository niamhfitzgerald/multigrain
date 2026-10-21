# UT3: information fractions that never reach 1 are accepted silently, and the level is never spent in full
# Run: Rscript UT3.R   (needs a gsd-build or gsd-build-spending build of multigrain, and gsDesign)
# fmt: skip file
library(multigrain)

set.seed(1)
# both hypotheses true; the last analysis is at information fraction 0.8
raw <- simulate_pvalues_gsd(c(0.025, 0.025), info_frac = c(0.4, 0.8), nsim = 200000)
pv <- withCallingHandlers(
    transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L),
    warning = function(w) { cat("warning:", gsub("\\s+", " ", conditionMessage(w)), "\n"); invokeRestart("muffleWarning") }
)
out <- calc_power_pvals_gsd(pv, c(1, 0), matrix(c(0, 1, 1, 0), 2))
cat("type I error of H1 (all alpha on H1):", round(out$local_power[1], 4), " level: 0.025\n")
cat("spent by sfLDOF at information fraction 0.8:", signif(gsDesign::sfLDOF(0.025, 0.8)$spend, 4), "\n")
cat("EXPECTED: a warning that H1 and H2 never reach an information fraction of 1 and spend only part of the level\n")
