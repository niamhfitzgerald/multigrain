# B1: start_graph is ignored when global_search = FALSE
# Run: Rscript B1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.6, 0.3), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

w0 <- c(0.6, 0.35, 0.05)                                    # the suggested start graph
G0 <- rbind(c(0, 0.8, 0.2), c(0.7, 0, 0.3), c(0.9, 0.1, 0))
Gd <- matrix(0.5, 3, 3)                                     # the default start graph
diag(Gd) <- 0
cat("gain of the suggested start graph:", calc_power_pvals(P, w0, G0, custom_power = list(g = gain))$g, "\n")
cat("gain of the default start graph  :", calc_power_pvals(P, rep(1, 3) / 3, Gd, custom_power = list(g = gain))$g, "\n")

a <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent",
                    start_graph = list(list(hyp_weight = w0, trans_matrix = G0)))
b <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent")

# local_output$x0 holds w1, w2, G[1,2], G[2,1], G[3,1] of the point the search started from
cat("search started at, with start_graph   :", round(a$local_output$x0, 3), "\n")
cat("search started at, without start_graph:", round(b$local_output$x0, 3), "\n")
cat("result with start_graph   : weights", round(unname(a$hyp_weight), 3), "gain", a$power$trial_success, "\n")
cat("result without start_graph: weights", round(unname(b$hyp_weight), 3), "gain", b$power$trial_success, "\n")
cat("EXPECTED: with start_graph the search starts at 0.6 0.35 0.8 0.7 0.9, the suggested graph\n")
