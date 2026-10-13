# Every power field reports the always-continue trial, even when the gain
# applies a stopping rule.
source("_common.R")
stop <- "((t1 == 1) && (t2 == 1))"
expr <- sprintf("%s * ((t1 == 1) + (t2 == 1) + (t3 == 1)) + (1 - %s) * (r1 + r2 + r3)", stop, stop)
res <- calc_power_pvals_gsd(pv, w, G, custom_power = list(gain = trial_success_gsd(!!expr, K = 2, verbose = "silent"),
                                                        p_stop = trial_success_gsd(!!paste(stop, "+ 0 * t3"), K = 2, verbose = "silent")))
res$local_power           # power of H3 ignoring the rule
res$p_stop                # the rule fires in this share of trials
# Power of H3 under the rule, computed by hand from the decision times:
tm <- multigrain:::graph_shortcut_gsd(multigrain:::.gsd_kernel_matrix(pv), 0.025, w, G, 2L)$time
stopped <- tm[, 1] == 1 & tm[, 2] == 1
mean(tm[, 3] > 0 & !(stopped & tm[, 3] == 2))   # lower than res$local_power[3]
