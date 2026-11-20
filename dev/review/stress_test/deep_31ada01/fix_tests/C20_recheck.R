# C20 recheck: a custom_power entry of the wrong type is always called "a string"
# Run: Rscript C20_recheck.R   (about 5 s)
# fmt: skip file
suppressMessages(library(multigrain))
set.seed(1)
p <- simulate_pvalues(c(0.9, 0.8), nsim = 100)
pg <- transform_pvalues_gsd(simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 100),
                            spending = function(a, t) gsDesign::sfLDOF(a, t)$spend)
G <- matrix(c(0, 1, 1, 0), 2)
for (x in list(3, NULL, TRUE)) {
    m1 <- tryCatch(calc_power_pvals(p, c(0.5, 0.5), G, custom_power = list(gain = x)), error = function(e) conditionMessage(e))
    m2 <- tryCatch(calc_power_pvals_gsd(pg, c(0.5, 0.5), G, custom_power = list(gain = x)), error = function(e) conditionMessage(e))
    cat(sprintf("custom_power = list(gain = %s)\n  calc_power_pvals():     %s\n  calc_power_pvals_gsd(): %s\n",
                deparse(x), gsub("\\s+", " ", m1), gsub("\\s+", " ", m2)))
}
cat("EXPECTED: \"not a number\", \"not NULL\" and \"not `TRUE`\" from both functions\n")
