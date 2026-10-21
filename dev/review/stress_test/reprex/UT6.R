# UT6: the design record's suggested way to supply the classical O'Brien-Fleming boundary fails
# Run from the repository root: Rscript UT6.R   (needs a gsd-build or gsd-build-spending build of multigrain, and gsDesign)
# fmt: skip file
library(multigrain)

rec <- readLines("dev/gsd_design_record.md", warn = FALSE)
cat("the record suggests it at line", grep("sfu = \"OF\", timing = t)", rec, fixed = TRUE), "\n")
of_sf <- function(a, t) cumsum(gsDesign::gsDesign(k = length(t), test.type = 1, alpha = a, sfu = "OF", timing = t)$upper$spend)
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.7, 1), nsim = 500)
msg <- tryCatch({ transform_pvalues_gsd(raw, spending = of_sf, grid_size = 64L); "accepted" },
                error = function(e) gsub("\\s+", " ", conditionMessage(e)))
cat("transform_pvalues_gsd(spending = <that function>):", msg, "\n")
cat("EXPECTED: the suggested function is accepted, or the record gives one that is\n")
