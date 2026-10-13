# A rule written on r instead of t compiles and means "rejected by the end",
# not "rejected at the interim". No warning.
source("_common.R")
on_t <- trial_success_gsd(!!"((t1 == 1) && (t2 == 1)) + 0 * t3", K = 2, verbose = "silent")
on_r <- trial_success_gsd(!!"(r1 && r2) + 0 * t3", K = 2, verbose = "silent")
calc_power_pvals_gsd(pv, w, G, custom_power = list(on_t = on_t, on_r = on_r))[c("on_t", "on_r")]
