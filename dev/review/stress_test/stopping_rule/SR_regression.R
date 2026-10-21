# fmt: skip file
# Run under two builds (ee91a11 and 8af8adb; then 8af8adb and 5585caf); saves results for
# a no-rule comparison. Usage: Rscript SR_regression.R <out.rds>
suppressMessages(library(multigrain))
out <- list()
for (cfg in list(list(m = 2, K = 2), list(m = 3, K = 3), list(m = 4, K = 2), list(m = 5, K = 4))) {
    set.seed(1000 + cfg$m * 10 + cfg$K)
    corr <- matrix(0.4, cfg$m, cfg$m); diag(corr) <- 1
    raw <- simulate_pvalues_gsd(power_nominal = seq(0.9, 0.6, length.out = cfg$m), corr_matrix = corr, info_frac = seq_len(cfg$K) / cfg$K, nsim = 3000)
    pv <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
    w <- rep(1 / cfg$m, cfg$m); G <- matrix(1 / (cfg$m - 1), cfg$m, cfg$m); diag(G) <- 0
    gain <- trial_success_gsd(!!str2lang(paste(sprintf("r%d * d(t%d)", seq_len(cfg$m), seq_len(cfg$m)), collapse = " + ")),
                              d = seq(1, 0.6, length.out = cfg$K), verbose = "silent")
    key <- sprintf("m%d_K%d", cfg$m, cfg$K)
    out[[paste0(key, "_pv")]] <- unclass(pv)[c("pvals", "info_frac")]
    out[[paste0(key, "_power")]] <- calc_power_pvals_gsd(pv, w, G, custom_power = list(gain = gain))
    set.seed(7)
    fit <- graph_optimise_gsd(pv, graph_constraint_free(cfg$m), gain, num_threads = 1, verbose = "silent")
    out[[paste0(key, "_opt")]] <- list(w = fit$hyp_weight, G = fit$trans_matrix, gain = fit$power$trial_success)
}
saveRDS(out, commandArgs(TRUE)[1])
