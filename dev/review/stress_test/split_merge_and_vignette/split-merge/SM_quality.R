# fmt: skip file
# Does the split-merge mutation find better graphs than the truncated Cauchy mutation? Same problems, same seeds,
# same simulated trials on two builds; each returned graph is then scored on 100,000 fresh trials, so the
# comparison is free of the in-sample optimism of the reported gain.
# Usage: R_LIBS=<build> Rscript SM_quality.R <out.rds>
suppressMessages({ library(multigrain); library(data.table) })
options(multigrain.verbosity = "silent", multigrain_verbosity = "silent")
block_corr <- function(m) { S <- matrix(0.2, m, m); for (i in seq(1, m, 2)) S[i:min(i + 1, m), i:min(i + 1, m)] <- 0.5; diag(S) <- 1; S }
probs <- list(
    P4w = list(m = 4, pw = c(0.9, 0.85, 0.7, 0.6), gain = quote(0.4 * r1 + 0.3 * r2 + 0.2 * r3 + 0.1 * r4), seeds = 1:5),
    P4g = list(m = 4, pw = c(0.9, 0.85, 0.7, 0.6), gain = quote((r1 || r2) * (0.6 + 0.2 * r3 + 0.2 * r4)), seeds = 1:5),
    P6w = list(m = 6, pw = c(0.9, 0.85, 0.8, 0.7, 0.6, 0.5), gain = quote(0.3 * r1 + 0.25 * r2 + 0.2 * r3 + 0.1 * r4 + 0.1 * r5 + 0.05 * r6), seeds = 1:3)
)
rows <- list()
for (nm in names(probs)) {
    pr <- probs[[nm]]
    set.seed(100 + pr$m); P <- simulate_pvalues(pr$pw, corr_matrix = block_corr(pr$m), nsim = 1e4)
    set.seed(900 + pr$m); Pf <- simulate_pvalues(pr$pw, corr_matrix = block_corr(pr$m), nsim = 1e5)
    gain <- trial_success(!!pr$gain, verbose = "silent")
    for (s in pr$seeds) {
        set.seed(s)
        t0 <- proc.time()[["elapsed"]]
        fit <- graph_optimise(P, graph_constraint_free(pr$m), gain, num_threads = 1, verbose = "silent")
        el <- proc.time()[["elapsed"]] - t0
        fresh <- calc_power_pvals(Pf, fit$hyp_weight, fit$trans_matrix, custom_power = list(g = gain))$g
        rows[[length(rows) + 1]] <- data.table(problem = nm, seed = s, reported = fit$power$trial_success, fresh = fresh, seconds = el,
                                               w = list(fit$hyp_weight), G = list(fit$trans_matrix))
    }
}
saveRDS(rbindlist(rows), commandArgs(TRUE)[1])
