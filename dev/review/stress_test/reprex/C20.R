# C20: a custom_power entry named like a built-in output field is hidden behind it
# Run: Rscript C20.R   (needs the gsd-build build of multigrain)
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
cat("EXPECTED: an error for the name `disj_power`, and \"not a number\" in the last message\n")
