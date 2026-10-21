# C20: a custom_power entry named like a built-in output field is hidden behind it
# Run: Rscript C20.R   (needs a gsd-build or gsd-build-spending build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2

# the user's own "disjunctive power": H1 or H2, leaving H3 out
out <- calc_power_pvals(pvals, w, G,
                        custom_power = list(disj_power = function(x) x[1] || x[2]))
cat("names of the result:", names(out), "\n")
cat("out$disj_power:", out$disj_power, " (the built-in value: any of the three)\n")
cat("out[[5]]:      ", out[[5]], " (the user's value, reachable by position only)\n")

# second face: an element of the wrong type is always described as "a string"
msg <- tryCatch(calc_power_pvals(pvals, w, G, custom_power = list(a = 3)),
                error = function(e) conditionMessage(e))
cat("custom_power = list(a = 3):", gsub("\\s+", " ", msg), "\n")

# third face: two of the nine fields of calc_power_pvals_gsd() came with the stopping rule,
# so a measure that was reachable by name before it is now hidden behind one of them
raw <- simulate_pvalues_gsd(c(0.9, 0.8, 0.7), info_frac = c(0.5, 1), nsim = 2000)
pv <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
out <- calc_power_pvals_gsd(pv, w, G, custom_power = list(mean_stop_look = function(t) 99))
cat("calc_power_pvals_gsd(custom_power = list(mean_stop_look = ...))$mean_stop_look:", out$mean_stop_look, "\n")
cat("EXPECTED: an error for the names `disj_power` and `mean_stop_look`, and \"not a number\" in the second message\n")
