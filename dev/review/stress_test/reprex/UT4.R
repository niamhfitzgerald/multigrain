# UT4: summary() of an unnamed list of spending functions prints deparsed code
# Run: Rscript UT4.R   (needs a gsd-build or gsd-build-spending build of multigrain, and gsDesign)
# fmt: skip file
library(multigrain)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 500)
pv <- transform_pvalues_gsd(raw, spending = list(gsDesign::sfLDOF, gsDesign::sfLDPocock), grid_size = 64L)
cat("labels stored:", paste0("\"", pv$spending, "\"", collapse = ", "), "\n")
cat("EXPECTED: \"gsDesign::sfLDOF\", \"gsDesign::sfLDPocock\"\n")
