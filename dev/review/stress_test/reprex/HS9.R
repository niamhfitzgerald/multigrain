# HS9: the article's fresh-draws check cannot show the optimism it is introduced to measure
# Run from the repository root: Rscript HS9.R   (about 1 minute; needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
stored <- readRDS("vignettes/articles/data/gsd-joint-spending.rds")
mj <- stored$main_joint
g_star <- unname(mj$spending_param[[1]])
cat("reported gain:", round(mj$power$trial_success, 4), "  fresh-draws gain:", round(stored$main_check$gain, 4), "\n")
# the article's fresh draws, scored in 20 batches of 5,000 to get a standard error
gain <- trial_success_gsd(0.6 * d(t1) + 0.4 * d(t2), d = c(1, 0.8))
set.seed(20261008)
raw <- simulate_pvalues_gsd(power_nominal = c(H1 = 0.90, H2 = 0.80), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2),
                            info_frac = c(0.5, 1), nsim = 1e5)
sf <- function(alpha, t) gsDesign::sfHSD(alpha, t, g_star)$spend
score <- function(rows) {
    pv <- transform_pvalues_gsd(raw[rows, , , drop = FALSE], info_frac = c(0.5, 1), spending = list(gsDesign::sfLDOF, sf))
    calc_power_pvals_gsd(pv, hyp_weight = mj$hyp_weight, trans_matrix = mj$trans_matrix,
                         stopping_rule = stopping_rule_gsd(r1), custom_power = list(gain = gain))$gain
}
b <- vapply(split(seq_len(1e5), rep(1:20, each = 5000)), score, numeric(1))
cat("fresh gain, recomputed:", round(mean(b), 4), "  standard error:", round(sd(b) / sqrt(20), 4), "\n")
cat("EXPECTED: an optimism (reported minus fresh) larger than its standard error, or the standard error quoted beside it\n")
