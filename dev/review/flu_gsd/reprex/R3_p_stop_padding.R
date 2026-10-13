# The stopping probability needs a dummy gain padded to the right m.
source("_common.R")
p_stop <- trial_success_gsd(!!"((t1 == 1) && (t2 == 1))", K = 2, verbose = "silent")
p_stop$m   # 2, although the design has 3 hypotheses
try(calc_power_pvals_gsd(pv, w, G, custom_power = list(p_stop = p_stop)))
# The message says the numbers of hypotheses disagree but not that the gain
# simply never mentions H3. The fix is a zero term:
p_stop <- trial_success_gsd(!!"((t1 == 1) && (t2 == 1)) + 0 * t3", K = 2, verbose = "silent")
calc_power_pvals_gsd(pv, w, G, custom_power = list(p_stop = p_stop))$p_stop
