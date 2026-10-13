# Task 5, second part: is a separate gamma per hypothesis worth it?
# One coordinate pass: starting from the best shared gamma, each hypothesis in
# turn tries the other values on a coarse grid while the rest keep theirs,
# and keeps the best. The graph is re-optimised at every step. A full
# factorial over five gammas is not feasible (see the write-up).
# Run from this folder: Rscript 03b_gamma_per_hypothesis.R [rule] [S] [gamma0]
source("00_setup.R"); source("run_scenarios.R")

args <- commandArgs(trailingOnly = TRUE)
rule   <- if (length(args) >= 1) args[1] else "protocol"
S      <- if (length(args) >= 2) as.numeric(args[2]) else 2
gamma0 <- if (length(args) >= 3) as.numeric(args[3]) else 1
grid   <- c(-4, -1, 1)

gain <- make_gain(S, rule)
pdes <- score_graph(pvals_for("test", "protocol"), protocol_graph, S, "protocol")
pv_vec <- function(which, gammas) {
  key <- sprintf("%s gammas %s", which, paste(gammas, collapse = ","))
  if (is.null(.pv_cache[[key]])) {
    z <- if (which == "train") { if (is.null(z_train)) z_train <<- simulate_z(1e5, train_seed); z_train
    } else { if (is.null(z_test)) z_test <<- simulate_z(1e5, test_seed); z_test }
    .pv_cache[[key]] <- make_pvals(z, spending_set(gamma = gammas))
  }
  .pv_cache[[key]]
}
run_vec <- function(gammas) {
  tag <- sprintf("gammavec__%s__S%.2f__%s", rule, S, paste(sprintf("%+.0f", gammas), collapse = ""))
  runs <- optimise_graph(pv_vec("train", gammas), gain, tag, seeds = optim_seeds[1])
  g <- as_graph(best_run(runs)); opt <- score_graph(pv_vec("test", gammas), g, S, rule)
  e <- graph_edges_text(g)
  data.table(as.data.table(as.list(setNames(gammas, paste0("gamma_", ids)))),
             gain = opt$gain, se = opt$se, p_stop = opt$p_stop,
             diff_vs_protocol_design = paired(opt$per_trial, pdes$per_trial)[["diff"]],
             se_design = paired(opt$per_trial, pdes$per_trial)[["se"]],
             as.data.table(as.list(setNames(opt$power, paste0("pow_", ids)))),
             initial = e$initial, edges = e$edges)
}

current <- rep(gamma0, m)
res <- run_vec(current)
res[, step := "start"]
for (i in seq_len(m)) {
  tried <- rbindlist(lapply(setdiff(grid, current[i]), function(g) {
    gg <- current; gg[i] <- g
    r <- run_vec(gg); r[, step := sprintf("%s = %+.0f", ids[i], g)]; r
  }))
  res <- rbind(res, tried)
  best_i <- res[which.max(gain)]
  current <- as.numeric(best_i[, paste0("gamma_", ids), with = FALSE])
  cat(sprintf("after %s: best gammas %s, gain %.3f\n", ids[i], paste(current, collapse = " "), best_i$gain))
}
fwrite(res, result_path(sprintf("gamma_per_hyp__%s__S%.2f.csv", rule, S)))
print(res[, c("step", paste0("gamma_", ids), "gain", "se", "p_stop", "diff_vs_protocol_design"), with = FALSE], row.names = FALSE)
