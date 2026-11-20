# fmt: skip file
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent", warn = 1)
sf_of <- function(a, t) gsDesign::sfLDOF(a, t)$spend
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), info_frac = c(0.5, 1), nsim = 200)
pv  <- transform_pvalues_gsd(raw, spending = sf_of, grid_size = 64L)
pv1 <- transform_pvalues_gsd(raw[1, , , drop = FALSE], info_frac = c(0.5, 1), spending = sf_of, grid_size = 64L)
spec <- transform_pvalues_gsd(raw, spending = list(sf_of, sf_hsd_opt(bounds = c(-2, 1), step = 0.5)), grid_size = 64L)
w <- c(0.5, 0.5); G <- matrix(c(0, 1, 1, 0), 2)
gain    <- trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75))
gain_k3 <- trial_success_gsd(r1 * d(t1) + r2, d = c(1, 0.75, 0.5))
gain_fs <- trial_success(r1 + r2)
gain_const <- trial_success_gsd(0 * r1 + 0 * r2 + 1)
