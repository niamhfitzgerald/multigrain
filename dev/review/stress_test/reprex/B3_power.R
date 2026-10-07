# B3_power: calc_power_pvals() accepts missing p-values and any alpha
# Run: Rscript B3_power.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2
cat("local power, complete p-values:      ", calc_power_pvals(pvals, w, G)$local_power, "\n")

with_na <- pvals
with_na[1:600, 2] <- NA                      # H2 not available in 30% of the trials
cat("local power, 600 p-values of H2 NA:  ", calc_power_pvals(with_na, w, G)$local_power, "\n")

negative <- rbind(c(-1, 0.9, 0.02))          # H1 has weight 0 below
hit <- calc_power_pvals(negative, c(0, 0.5, 0.5), G)$local_power
cat("rejected for p = (-1, 0.9, 0.02), w = (0, 0.5, 0.5):", hit == 1, "\n")

cat("local power at alpha = 40:           ", calc_power_pvals(pvals, w, G, alpha = 40)$local_power, "\n")
cat("EXPECTED: an error for each of the last three calls, as calc_power_pvals_gsd() gives\n")
