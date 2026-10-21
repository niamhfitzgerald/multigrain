# fmt: skip file
# Run under two builds (main and fast-shortcut) and compare the saved results.
# Usage: Rscript FS_identity.R <out.rds>
suppressMessages(library(multigrain))
out <- list(); tim <- list()
for (cfg in list(list(m = 3, n = 4000), list(m = 4, n = 6000), list(m = 6, n = 6000), list(m = 8, n = 4000))) {
    set.seed(10 * cfg$m)
    S <- matrix(0.4, cfg$m, cfg$m); diag(S) <- 1
    P <- simulate_pvalues(seq(0.9, 0.6, length.out = cfg$m), corr_matrix = S, nsim = cfg$n)
    gain <- trial_success(!!str2lang(paste(sprintf("%.2f * r%d", seq(1, 0.5, length.out = cfg$m), seq_len(cfg$m)), collapse = " + ")), verbose = "silent")
    for (thr in c(1L, 2L)) {
        key <- sprintf("m%d_t%d", cfg$m, thr)
        set.seed(7)
        fit <- graph_optimise(P, graph_constraint_free(cfg$m), gain, num_threads = thr, verbose = "silent")
        out[[key]] <- list(w = fit$hyp_weight, G = fit$trans_matrix, power = fit$power)
    }
    w <- rep(1 / cfg$m, cfg$m); G <- matrix(1 / (cfg$m - 1), cfg$m, cfg$m); diag(G) <- 0
    out[[sprintf("m%d_power", cfg$m)]] <- calc_power_pvals(P, w, G, custom_power = list(g = gain))
}
# timings of one power calculation, 1e5 trials
for (m in c(4, 8, 12)) {
    set.seed(m); P <- matrix(runif(1e5 * m)^3, ncol = m)
    w <- rep(1 / m, m); G <- matrix(1 / (m - 1), m, m); diag(G) <- 0
    tim[[as.character(m)]] <- median(replicate(5, system.time(calc_power_pvals(P, w, G))[["elapsed"]]))
}
out$timing <- tim
saveRDS(out, commandArgs(TRUE)[1])
