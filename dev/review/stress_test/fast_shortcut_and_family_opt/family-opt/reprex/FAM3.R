# FAM3: a custom_power entry named family_power is hidden behind the built-in field (C20)
# Run: Rscript FAM3.R   (needs the family-opt build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))

set.seed(3)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
fs <- family_spec(list(1, 2:3))
mine <- trial_success(r1 + r2 + r3, verbose = "silent")
out <- calc_power_pvals(P, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2), families = fs,
                        custom_power = list(family_power = mine))
cat("entries named family_power:", sum(names(out) == "family_power"), "\n")
cat("out$family_power returns  :", format(out$family_power, digits = 3), "\n")
cat("the user's measure        :", calc_power_pvals(P, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2), families = fs,
                                                     custom_power = list(x = mine))$x, "\n")
cat("EXPECTED: an error for a name that clashes with a built-in field\n")
