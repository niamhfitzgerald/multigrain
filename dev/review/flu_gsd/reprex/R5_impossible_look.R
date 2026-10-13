# A look that cannot occur, or a rule that can never fire, gives a gain that
# is identically zero. The optimiser accepts it and returns a graph.
source("_common.R")
g <- trial_success_gsd(!!"(t1 == 3) * (r1 + r2 + r3)", K = 2, verbose = "silent")   # K = 2, so t1 == 3 is impossible
calc_power_pvals_gsd(pv, w, G, custom_power = list(g = g))$g     # 0
# Rule that can never be met on this graph: H3 holds no alpha at the interim
# unless H1 and H2 are rejected first; require H3 alone at look 1 with
# the fixed sequence H1 -> H2 -> H3 and H3 before H2 is impossible.
never <- trial_success_gsd(!!"((t3 == 1) && (t2 == 0)) * (r1 + r2 + r3)", K = 2, verbose = "silent")
calc_power_pvals_gsd(pv, w, G, custom_power = list(never = never))$never   # 0
cons <- graph_constraint(hyp_constraint = c(1, 0, 0))
opt <- graph_optimise_gsd(pv, cons, never, global_search = FALSE, verbose = "silent")
opt$hyp_weight; opt$trans_matrix          # a graph is returned for a constant objective
