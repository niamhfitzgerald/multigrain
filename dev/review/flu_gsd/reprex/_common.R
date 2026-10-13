# Shared toy design for the reprexes: three hypotheses, two analyses, all
# alpha on H1, H1 -> H2 -> H3. No trial inputs are used here.
suppressPackageStartupMessages(library(multigrain))
set.seed(1)
corr <- matrix(0.5, 3, 3); diag(corr) <- 1
raw <- simulate_pvalues_gsd(c(0.95, 0.8, 0.6), corr_matrix = corr, info_frac = c(0.5, 1), nsim = 2e4)
pv  <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDPocock, alpha = 0.025)
w <- c(1, 0, 0)
G <- rbind(c(0, 1, 0), c(0, 0, 1), c(1, 0, 0))
