# C21: calc_power_pvals_gsd() refuses a gain that does not mention the last hypothesis
# Run: Rscript C21.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 2000)
pvals <- transform_pvalues_gsd(raw, spending = sfLDOF, grid_size = 128L)
w <- c(0.5, 0.5)
G <- matrix(c(0, 1, 1, 0), 2)

# power to reject H1 at the interim, on a design with two hypotheses
h1_interim <- trial_success_gsd((t1 == 1) + 0, verbose = "silent")
res <- tryCatch(calc_power_pvals_gsd(pvals, w, G, custom_power = list(g = h1_interim))$g,
                error = function(e) conditionMessage(e))
cat("gain (t1 == 1) + 0:         ", res, "\n")

padded <- trial_success_gsd((t1 == 1) + 0 * r2, verbose = "silent")
cat("gain (t1 == 1) + 0 * r2:    ", calc_power_pvals_gsd(pvals, w, G, custom_power = list(g = padded))$g, "\n")
cat("local power of H1, analysis 1:", calc_power_pvals_gsd(pvals, w, G)$local_power_by_analysis[1, 1], "\n")
cat("EXPECTED: the same number from all three lines\n")
