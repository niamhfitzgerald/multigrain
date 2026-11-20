# DS2: alpha is checked against [0, 1] with both ends allowed, so a level of 0 or 1 is accepted, or fails inside gsDesign
# Run: Rscript DS2.R   (a few seconds)
# fmt: skip file
suppressMessages(library(multigrain))
try_it <- function(label, expr) cat(sprintf("%-50s %s\n", label, tryCatch({ v <- expr; sprintf("values from %g to %g", min(v), max(v)) },
                                    error = function(e) paste("error:", gsub("\\s+", " ", conditionMessage(e))))))
for (a in c(0, 1)) try_it(sprintf("simulate_pvalues(alpha = %g):", a), simulate_pvalues(c(0.9, 0.8), alpha = a, nsim = 5))
for (a in c(0, 1)) try_it(sprintf("simulate_pvalues_gsd(alpha = %g):", a), simulate_pvalues_gsd(c(0.9, 0.8), alpha = a, info_frac = c(0.5, 1), nsim = 5))
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 50)
of  <- function(a, t) gsDesign::sfLDOF(a, t)$spend
lin <- function(a, t) a * pmin(t, 1)
for (a in c(0, 1)) try_it(sprintf("transform_pvalues_gsd(alpha = %g), sfLDOF:", a), transform_pvalues_gsd(raw, spending = of, alpha = a)$pvals)
for (a in c(0, 1)) try_it(sprintf("transform_pvalues_gsd(alpha = %g), a * pmin(t, 1):", a), transform_pvalues_gsd(raw, spending = lin, alpha = a)$pvals)
for (a in c(0, 1)) try_it(sprintf("calc_ncp(0.9, alpha = %g):", a), calc_ncp(0.9, alpha = a))
cat("EXPECTED: an error from multigrain naming alpha, which must be greater than 0 and less than 1\n")
