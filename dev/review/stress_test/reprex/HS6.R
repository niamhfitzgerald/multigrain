# HS6: a value above the lattice is told its nearest nodes are "0 and NA"
# Run: Rscript HS6.R   (needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
set.seed(1)
raw  <- array(stats::runif(200 * 2 * 2), dim = c(200L, 2L, 2L))
spec <- transform_pvalues_gsd(raw, info_frac = c(0.5, 1), grid_size = 64L,
                              spending = list(gsDesign::sfLDOF, sf_hsd_opt(bounds = c(-1, 0), step = 0.5)))
for (v in c(5, -5)) cat(sprintf("resolve_pvalues_gsd(spec, %2d): %s\n", v, tryCatch({ resolve_pvalues_gsd(spec, v); "ran" },
    error = function(e) gsub("\\s+", " ", paste(conditionMessage(e), collapse = " ")))))
cat("EXPECTED: for 5, a message that the value is outside the lattice and the nearest node is 0\n")
