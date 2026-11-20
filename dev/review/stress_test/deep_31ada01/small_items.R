# fmt: skip file
# Two small items that no D1 case records: the spending message at tiny levels, and a repeated information fraction.
# The other small items in the README are rows of D1_sweep.tsv. Usage: R_LIBS=<build> Rscript small_items.R
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
said <- function(expr) tryCatch({ expr; "accepted" }, error = function(e) paste("error:", gsub("\\s+", " ", conditionMessage(e))))
of <- function(a, t) gsDesign::sfLDOF(a, t)$spend
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 50)
for (a in c(1e-11, 1e-12, 1e-13, 1e-15)) {
    cat(sprintf("alpha %g: sfLDOF spends %.6g at t = 1\n  transform: %s\n", a, gsDesign::sfLDOF(a, c(0.5, 1))$spend[2],
                said(transform_pvalues_gsd(raw, spending = of, alpha = a))))
}
set.seed(2)
dup <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 0.5, 1), nsim = 1000)
cat("info_frac = c(0.5, 0.5, 1): simulate_pvalues_gsd() accepted; transform:", said(transform_pvalues_gsd(dup, spending = of)), "\n")
