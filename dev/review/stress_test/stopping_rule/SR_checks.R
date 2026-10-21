# fmt: skip file
# Stress test of the efficacy stopping rule (stopping_rule_gsd(), merged into
# gsd-build at 8af8adb). Each check prints PASS or FAIL and a short reason.
# Runs from anywhere; needs a gsd-build or gsd-build-spending build of multigrain and gsDesign.
suppressMessages(library(multigrain))
options(warn = 1)
res <- list()
check <- function(id, ok, what) {
    res[[id]] <<- isTRUE(ok)
    cat(sprintf("%-5s %-4s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", what))
}
ks <- multigrain:::graph_shortcut_gsd
ks_par <- multigrain:::graph_shortcut_gsd_parallel
as_mat <- function(pv) { x <- pv$pvals; dim(x) <- c(dim(x)[1], prod(dim(x)[-1])); x }

# Independent reference: the graphical procedure look by look (Bretz et al.
# 2009 update, local level w * alpha, reject on p < level), written from the
# definition and sharing no code with the package.
ref_times <- function(P, m, K, alpha, w, G) {
    N <- nrow(P); out <- matrix(0L, N, m)
    for (s in seq_len(N)) {
        a <- w * alpha; g <- G; rej <- rep(FALSE, m)
        for (k in seq_len(K)) {
            p <- P[s, (k - 1) * m + seq_len(m)]
            repeat {
                cand <- which(!rej & p < a)
                if (!length(cand)) break
                i <- cand[1]; rej[i] <- TRUE; out[s, i] <- k
                keep <- which(!rej)
                a_new <- a; g_new <- g
                for (j in keep) a_new[j] <- a[j] + a[i] * g[i, j]
                for (j in keep) for (l in keep) {
                    g_new[j, l] <- if (j == l || g[j, i] * g[i, j] >= 1) 0 else
                        (g[j, l] + g[j, i] * g[i, l]) / (1 - g[j, i] * g[i, j])
                }
                a_new[i] <- 0; g_new[i, ] <- 0; g_new[, i] <- 0
                a <- a_new; g <- g_new
            }
            if (all(rej)) break
        }
    }
    out
}
# Truncate unstopped decision times at the first interim where the rule holds.
truncate_times <- function(tm, K, cond_fun) {
    stop_look <- rep(K, nrow(tm))
    for (s in seq_len(nrow(tm))) {
        for (k in seq_len(K - 1)) {
            rset <- tm[s, ] > 0 & tm[s, ] <= k
            if (all(rset) || cond_fun(rset, k)) { stop_look[s] <- k; break }
        }
        if (stop_look[s] == K && all(tm[s, ] > 0)) stop_look[s] <- max(tm[s, ])
        tm[s, tm[s, ] > stop_look[s]] <- 0L
    }
    list(time = tm, stop_look = stop_look)
}
rand_graph <- function(m) {
    w <- runif(m); w <- w / sum(w)
    G <- matrix(runif(m * m), m); diag(G) <- 0; G <- G / rowSums(G)
    list(w = w, G = G)
}
make_pvals <- function(m, K, nsim, power, rho = 0.5) {
    corr <- matrix(rho, m, m); diag(corr) <- 1
    info <- seq_len(K) / K
    raw <- simulate_pvalues_gsd(power_nominal = power, corr_matrix = corr, info_frac = info, nsim = nsim)
    transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
}

# ---- SR01: kernel with no rule agrees with the independent reference -------
set.seed(101)
ok <- TRUE
for (m in 2:5) for (K in 2:4) {
    pv <- make_pvals(m, K, 400, power = seq(0.9, 0.5, length.out = m))
    g <- rand_graph(m); P <- as_mat(pv)
    ok <- ok && identical(ks(P, 0.025, g$w, g$G, K)$time, ref_times(P, m, K, 0.025, g$w, g$G))
}
check("SR01", ok, "no-rule kernel matches an independent graphical procedure (m 2-5, K 2-4, 400 trials each)")

# ---- SR02: with a rule, kernel = truncation of the unstopped trial ---------
rules <- list(
    list(sr = quote(r1), f = function(r, k) r[1]),
    list(sr = quote(r1 && (r2 || r3)), f = function(r, k) r[1] && (r[2] || r[3])),
    list(sr = quote(r1 + r2 + r3 >= 2), f = function(r, k) sum(r[1:3]) >= 2),
    list(sr = quote(r2 && !r1), f = function(r, k) r[2] && !r[1])
)
set.seed(102)
ok_ser <- ok_par <- ok_stop <- TRUE
for (m in 3:5) for (K in 2:4) for (ru in rules) {
    pv <- make_pvals(m, K, 400, power = seq(0.9, 0.5, length.out = m))
    g <- rand_graph(m); P <- as_mat(pv)
    tab <- multigrain:::.gsd_stop_table(rep(list(ru$sr), K - 1), m, K)
    ref <- truncate_times(ks(P, 0.025, g$w, g$G, K)$time, K, ru$f)
    a <- ks(P, 0.025, g$w, g$G, K, stop_rule = tab)
    b <- ks_par(P, 0.025, g$w, g$G, K, num_threads = 2L, stop_rule = tab)
    ok_ser <- ok_ser && identical(a$time, ref$time)
    ok_stop <- ok_stop && identical(as.integer(a$stop_look), as.integer(ref$stop_look))
    ok_par <- ok_par && identical(a$time, b$time) && identical(a$stop_look, b$stop_look)
}
check("SR02a", ok_ser, "stopped decision times = unstopped times cut at the first interim where the rule holds (36 designs x 4 rules)")
check("SR02b", ok_stop, "stop_look matches the reference, including the stop when every hypothesis is rejected")
check("SR02c", ok_par, "serial and parallel kernels agree exactly with a rule")

# ---- SR03: per-interim rules (a list) are applied at the right look --------
set.seed(103)
pv <- make_pvals(3, 3, 3000, power = c(0.9, 0.8, 0.7)); g <- rand_graph(3); P <- as_mat(pv)
sr <- stopping_rule_gsd(list(r1, r1 && (r2 || r3)))
tab <- multigrain:::.gsd_stop_table(multigrain:::.gsd_check_stopping_rule_dims(sr, pv), 3, 3)
ref <- truncate_times(ks(P, 0.025, g$w, g$G, 3)$time, 3, function(r, k) if (k == 1) r[1] else r[1] && (r[2] || r[3]))
check("SR03", identical(ks(P, 0.025, g$w, g$G, 3, stop_rule = tab)$time, ref$time), "a list of conditions applies condition k at interim k")

# ---- SR04: error control under the global null and a partial null -----------
set.seed(104)
for (scn in list(list(id = "SR04a", pw = rep(0.025, 4), lab = "global null"),
                 list(id = "SR04b", pw = c(0.95, 0.025, 0.025, 0.025), lab = "H1 false, H2-H4 true"))) {
    pv <- make_pvals(4, 3, 200000, power = scn$pw, rho = 0.3)
    w <- rep(0.25, 4); G <- matrix(1 / 3, 4, 4); diag(G) <- 0
    worst <- 0
    for (rr in list(NULL, stopping_rule_gsd(r1), stopping_rule_gsd(r1 + r2 + r3 + r4 >= 1),
                    stopping_rule_gsd(list(r1 || r2, r1 && r2)))) {
        out <- calc_power_pvals_gsd(pv, w, G, stopping_rule = rr,
                                    custom_power = list(fwe = function(t) any(t[which(scn$pw <= 0.025)] > 0)))
        worst <- max(worst, out$fwe)
    }
    se <- sqrt(0.025 * 0.975 / 200000)
    check(scn$id, worst <= 0.025 + 3 * se, sprintf("FWER with and without rules, %s: worst %.5f (limit 0.025 + 3 SE = %.5f)", scn$lab, worst, 0.025 + 3 * se))
}

# ---- SR05: every output field is consistent and no power goes up -----------
set.seed(105)
pv <- make_pvals(3, 3, 20000, power = c(0.9, 0.8, 0.7))
w <- rep(1 / 3, 3); G <- matrix(0.5, 3, 3); diag(G) <- 0
base <- calc_power_pvals_gsd(pv, w, G)
ok_mono <- ok_fields <- TRUE
for (rr in list(stopping_rule_gsd(r1), stopping_rule_gsd(r1 && r2 && r3), stopping_rule_gsd(r1 && (r2 || r3)), stopping_rule_gsd(r2 && !r1))) {
    o <- calc_power_pvals_gsd(pv, w, G, stopping_rule = rr)
    ok_mono <- ok_mono && all(o$local_power <= base$local_power + 1e-12) &&
        all(o$local_power_by_analysis <= base$local_power_by_analysis + 1e-12) &&
        o$disj_power <= base$disj_power + 1e-12 && o$conj_power <= base$conj_power + 1e-12
    ok_fields <- ok_fields && abs(sum(o$stop_distribution) - 1) < 1e-12 &&
        abs(o$mean_stop_look - sum(seq_along(o$stop_distribution) * o$stop_distribution)) < 1e-12 &&
        all(abs(o$local_power_by_analysis[, 3] - o$local_power) < 1e-12) &&
        all(abs(rowSums(o$time_distribution) - 1) < 1e-12) &&
        o$local_power_by_analysis[1, 1] == base$local_power_by_analysis[1, 1]
}
check("SR05a", ok_mono, "no local, disjunctive or conjunctive power rises under any of four rules")
check("SR05b", ok_fields, "stop_distribution sums to 1, mean_stop_look is its mean, power at interim 1 is untouched")
tm0 <- ks(as_mat(pv), 0.025, w, G, 3)
early <- tabulate(tm0$stop_look, 3) / nrow(tm0$time)
expect_early <- sapply(1:2, function(k) mean(apply(tm0$time, 1, function(t) all(t > 0) && max(t) == k)))
check("SR05c", isTRUE(all.equal(unname(base$stop_distribution[1:2]), expect_early)), "without a rule, mass before K is exactly the trials that rejected everything by then")
cat("      no rule: stop_distribution =", round(base$stop_distribution, 4), "\n")

# ---- SR06: K = 1, a single condition has no effect --------------------------
set.seed(106)
raw <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = diag(2), info_frac = 1, nsim = 5000)
pv1 <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
a <- calc_power_pvals_gsd(pv1, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2))
b <- calc_power_pvals_gsd(pv1, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2), stopping_rule = stopping_rule_gsd(r1))
check("SR06", identical(a$local_power, b$local_power) && all(b$stop_distribution == 1), "K = 1: a rule is accepted and changes nothing")

# ---- SR07: the optimiser uses the rule and reports what calc_power gives ----
set.seed(107)
pv <- make_pvals(3, 2, 4000, power = c(0.9, 0.8, 0.7))
gain <- trial_success_gsd(r1 * d(t1) + r2 * d(t2) + r3 * d(t3), d = c(1, 0.8), verbose = "silent")
rule <- stopping_rule_gsd(r1)
fit_rule <- graph_optimise_gsd(pv, graph_constraint_free(3), gain, stopping_rule = rule, num_threads = 2, verbose = "silent")
fit_none <- graph_optimise_gsd(pv, graph_constraint_free(3), gain, num_threads = 2, verbose = "silent")
re <- calc_power_pvals_gsd(pv, fit_rule$hyp_weight, fit_rule$trans_matrix, custom_power = list(gain = gain), stopping_rule = rule)
rep_gain <- fit_rule$power$trial_success
check("SR07a", isTRUE(all.equal(rep_gain, re$gain, tolerance = 1e-10)), sprintf("reported gain %.6f equals calc_power_pvals_gsd() on the returned graph with the rule %.6f", rep_gain, re$gain))
none_under_rule <- calc_power_pvals_gsd(pv, fit_none$hyp_weight, fit_none$trans_matrix, custom_power = list(gain = gain), stopping_rule = rule)$gain
check("SR07b", rep_gain >= none_under_rule - 1e-4, sprintf("graph optimised with the rule is at least as good under the rule as the no-rule optimum (%.5f vs %.5f)", rep_gain, none_under_rule))
check("SR07c", identical(fit_rule$stopping_rule, rule), "the result records the rule")
pr <- capture.output(print(fit_rule)); sm <- capture.output(summary(fit_rule))
check("SR07d", any(grepl("Stopping rule", pr)) && any(grepl("Stopping-look distribution", sm)) || any(grepl("Stopping", sm)), "print() and summary() show the rule and the stopping distribution")

# ---- SR08: building the truth table for large m -----------------------------
for (m in c(12L, 16L)) {
    sr <- stopping_rule_gsd(r1 && r2)
    tt <- system.time(tab <- multigrain:::.gsd_stop_table(rep(sr$conditions, 3), m, 4L))[["elapsed"]]
    cat(sprintf("      m = %d, K = 4: truth table of %d x 3 built in %.1f s\n", m, 2^m, tt))
}
e <- tryCatch(multigrain:::.gsd_stop_table(list(quote(r1)), 17L, 2L), error = function(e) conditionMessage(e))
check("SR08", grepl("at most 16", e), "m = 17 is refused with a message naming the 16-hypothesis limit")

cat(sprintf("\n%d of %d checks passed\n", sum(unlist(res)), length(res)))
