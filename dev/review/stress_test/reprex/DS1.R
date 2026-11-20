# DS1: info_frac given to transform_pvalues_gsd() replaces the one the simulator attached, without a message
# Run: Rscript DS1.R   (about 5 s)
# fmt: skip file
suppressMessages(library(multigrain))
pocock <- function(a, t) gsDesign::sfLDPocock(a, t)$spend
set.seed(1)
raw <- simulate_pvalues_gsd(0.025, info_frac = c(0.2, 1), nsim = 2e5)    # power = alpha: the global null
cat("info_frac attached by the simulator:", attr(raw, "info_frac"), "\n")
ok    <- transform_pvalues_gsd(raw, spending = pocock)
later <- withCallingHandlers(transform_pvalues_gsd(raw, info_frac = c(0.8, 1), spending = pocock),
                             warning = function(w) cat("warning:", conditionMessage(w), "\n"),
                             message = function(m) cat("message:", conditionMessage(m)))
earlier <- transform_pvalues_gsd(raw, info_frac = c(0.1, 1), spending = pocock)
err <- function(pv) calc_power_pvals_gsd(pv, hyp_weight = 1, trans_matrix = matrix(0, 1, 1), sum_to_one_constraint = FALSE)$disj_power
cat(sprintf("type I error at 0.025: %.4f with the simulator's info_frac, %.4f with info_frac = c(0.8, 1), %.4f with c(0.1, 1); standard error %.4f\n",
            err(ok), err(later), err(earlier), sqrt(0.025 * 0.975 / 2e5)))
cat("EXPECTED: an error or a warning when info_frac differs from the info_frac attribute of pvals\n")
