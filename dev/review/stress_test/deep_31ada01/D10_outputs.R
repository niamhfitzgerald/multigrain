# fmt: skip file
# D10: internal consistency of every summary calc_power_pvals_gsd() returns, on random designs with and without a
# stopping rule. Each identity follows from the help page's definitions.
# Usage: R_LIBS=<build> Rscript D10_outputs.R
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "ref_lib.R"))
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
set.seed(1010); fails <- list(); n_checked <- 0
for (d in 1:60) {
    m <- sample(2:5, 1); K <- sample(2:4, 1)
    base <- c(sort(round(runif(K - 1, 0.15, 0.9), 2)), 1); while (any(diff(base) < 0.05)) base <- c(sort(round(runif(K - 1, 0.15, 0.9), 2)), 1)
    info <- matrix(base, m, K, byrow = TRUE); if (runif(1) < 0.3) info[sample(m, 1), 1] <- NA
    P <- sim_raw(3000, qnorm(runif(m, 0.3, 0.95)) + qnorm(0.975), { r <- matrix(0.4, m, m); diag(r) <- 1; r }, info)
    pv <- transform_pvalues_gsd(P, info_frac = info, spending = function(a, t) gsDesign::sfLDPocock(a, t)$spend, look_back = runif(m) < 0.3)
    w <- rexp(m); w <- w / sum(w); G <- matrix(rexp(m * m), m); diag(G) <- 0; G <- G / rowSums(G)
    rule <- if (d %% 2 == 0) stopping_rule_gsd(r1 || r2) else NULL
    o <- calc_power_pvals_gsd(pv, w, G, stopping_rule = rule)
    td <- o$time_distribution; lp <- o$local_power
    checks <- c(
        local_vs_never = isTRUE(all.equal(unname(lp), unname(1 - td[, "never"]))),
        last_column = isTRUE(all.equal(unname(o$local_power_by_analysis[, K]), unname(lp))),
        by_analysis_increasing = all(apply(o$local_power_by_analysis, 1, function(x) all(diff(x) >= -1e-12))),
        by_analysis_vs_time = isTRUE(all.equal(unname(o$local_power_by_analysis), unname(t(apply(td[, -1, drop = FALSE], 1, cumsum))))),
        time_rows_sum_1 = isTRUE(all.equal(unname(rowSums(td)), rep(1, m))),
        stop_sums_1 = isTRUE(all.equal(sum(o$stop_distribution), 1)),
        exp_rejections = isTRUE(all.equal(o$exp_rejections, sum(lp))),
        disj_bounds = o$disj_power >= max(lp) - 1e-12 && o$disj_power <= min(1, sum(lp)) + 1e-12,
        conj_bounds = o$conj_power <= min(lp) + 1e-12,
        mean_look = isTRUE(all.equal(unname(o$mean_decision_look), unname(ifelse(lp > 0, as.vector(td[, -1, drop = FALSE] %*% seq_len(K)) / lp, NA_real_)))),
        mean_stop = isTRUE(all.equal(o$mean_stop_look, sum(seq_len(K) * o$stop_distribution))))
    n_checked <- n_checked + length(checks)
    if (!all(checks)) fails[[length(fails) + 1]] <- list(design = d, failed = names(checks)[!checks])
}
cat(sprintf("60 designs (30 with a stopping rule), %d identities checked, %d failed\n", n_checked, length(unlist(lapply(fails, `[[`, "failed")))))
if (length(fails)) print(fails[1:min(5, length(fails))])
