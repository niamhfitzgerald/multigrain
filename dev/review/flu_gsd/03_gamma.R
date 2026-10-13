# Task 5. Optimise the Hwang-Shih-DeCani gamma alongside the graph.
#
# multigrain optimises the graph for a fixed set of repeated p-values, and the
# spending function is baked into those p-values by transform_pvalues_gsd().
# So gamma is optimised in an outer loop: for each gamma the training trials
# are re-transformed and the graph re-optimised (profile optimisation). One
# gamma is shared by all five hypotheses and constrained to [-4, 1]:
# -4 is close to O'Brien-Fleming and 1 is close to Pocock.
#
# Stage 1: grid gamma = -4, -3, ..., 1 (one optimiser seed each).
# Stage 2: refine at +-0.5 and +-0.25 around the best grid value.
# Stage 3: second seed for the two best gammas.
# Every run is scored on fresh test trials, and the gain is read off there.
# Run from this folder: Rscript 03_gamma.R [rule] [S]   (default: protocol 2)
source("00_setup.R"); source("run_scenarios.R")

args <- commandArgs(trailingOnly = TRUE)
rule <- if (length(args) >= 1) args[1] else "protocol"
S    <- if (length(args) >= 2) as.numeric(args[2]) else 2
gamma_bounds <- c(-4, 1)

pv_gamma <- function(which, gamma) {
  key <- sprintf("%s gamma %.4f", which, gamma)
  if (is.null(.pv_cache[[key]])) {
    z <- if (which == "train") {
      if (is.null(z_train)) z_train <<- simulate_z(1e5, train_seed)
      z_train
    } else {
      if (is.null(z_test)) z_test <<- simulate_z(1e5, test_seed)
      z_test
    }
    .pv_cache[[key]] <- make_pvals(z, spending_set(gamma = gamma))
  }
  .pv_cache[[key]]
}

gain <- make_gain(S, rule)
pv_protocol_design <- pvals_for("test", "protocol")
pdes <- score_graph(pv_protocol_design, protocol_graph, S, "protocol")

run_gamma <- function(gamma, seeds) {
  tag <- sprintf("gamma__%s__S%.2f__g%+.2f", rule, S, gamma)
  runs <- optimise_graph(pv_gamma("train", gamma), gain, tag, seeds = seeds)
  best <- best_run(runs); g <- as_graph(best)
  pv <- pv_gamma("test", gamma)
  opt  <- score_graph(pv, g, S, rule)
  prot <- score_graph(pv, protocol_graph, S, rule)   # protocol graph with this gamma
  e <- graph_edges_text(g)
  data.table(rule = rule, S = S, gamma = gamma, seeds = length(runs), seed_best = best$seed,
             train_gain = best$train_gain,
             gain = opt$gain, se = opt$se, p_stop = opt$p_stop,
             gain_protocol_graph = prot$gain,
             diff_vs_protocol_design = paired(opt$per_trial, pdes$per_trial)[["diff"]],
             se_design = paired(opt$per_trial, pdes$per_trial)[["se"]],
             as.data.table(as.list(setNames(opt$power, paste0("pow_", ids)))),
             initial = e$initial, edges = e$edges)
}

# Stage 1
grid <- seq(gamma_bounds[1], gamma_bounds[2], by = 1)
res <- rbindlist(lapply(grid, run_gamma, seeds = optim_seeds[1]))
# Stage 2
g_best <- res[which.max(gain), gamma]
refine <- setdiff(g_best + c(-0.5, -0.25, 0.25, 0.5), res$gamma)
refine <- refine[refine >= gamma_bounds[1] & refine <= gamma_bounds[2]]
res <- rbind(res, rbindlist(lapply(refine, run_gamma, seeds = optim_seeds[1])))
# Stage 3
top2 <- res[order(-gain)][1:2, gamma]
res <- rbind(res[!gamma %in% top2], rbindlist(lapply(top2, run_gamma, seeds = optim_seeds)))
setorder(res, gamma)

file <- result_path(sprintf("gamma__%s__S%.2f.csv", rule, S))
fwrite(res, file)
cat(sprintf("\nTask 5: shared HSD gamma, rule = %s, S = %g\n", rule, S))
print(res[, .(gamma, seeds, train_gain = fmt(train_gain), gain = fmt(gain), se = fmt(se, 3),
              protocol_graph = fmt(gain_protocol_graph), p_stop = fmt(p_stop, 3),
              vs_protocol_design = sprintf("%s (%s)", fmt(diff_vs_protocol_design), fmt(se_design, 3)))],
      row.names = FALSE)
cat("\nBest gamma:", res[which.max(gain), gamma], "\n")
print(res[which.max(gain), .(initial, edges)], row.names = FALSE)
