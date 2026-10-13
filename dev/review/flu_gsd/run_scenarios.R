# Optimises and evaluates a set of scenarios (stopping rule, spending set,
# value S). Sourced by the task scripts after 00_setup.R.
#
# run_scenarios(sc) where sc is a data.table with columns rule, spending, S:
#   - optimises the graph for each scenario on the training trials (resumable,
#     one run per seed in runs/);
#   - scores the protocol graph and the best optimised graph on fresh test
#     trials, with paired Monte Carlo SEs against the protocol graph (same rule
#     and spending) and against the protocol design (protocol graph, protocol
#     spending, protocol stopping rule, same S);
#   - writes results/scenarios.csv (merged with earlier scenarios) and
#     results/graphs.csv, and returns the rows for sc.

z_train <- NULL; z_test <- NULL
.pv_cache <- new.env()
pvals_for <- function(which = c("train", "test"), spending) {
  which <- match.arg(which)
  key <- paste(which, spending)
  if (is.null(.pv_cache[[key]])) {
    if (which == "train") {
      if (is.null(z_train)) z_train <<- simulate_z(1e5, train_seed)
      z <- z_train
    } else {
      if (is.null(z_test)) z_test <<- simulate_z(1e5, test_seed)
      z <- z_test
    }
    .pv_cache[[key]] <- make_pvals(z, spending_set(spending))
  }
  .pv_cache[[key]]
}

run_scenarios <- function(sc, seeds = optim_seeds) {
  sc <- as.data.table(sc)
  sc[, tag := scenario_tag(rule, spending, S)]

  # 1. Optimise
  runs <- lapply(seq_len(nrow(sc)), function(i) {
    with(sc[i], optimise_graph(pvals_for("train", spending), make_gain(S, rule), tag, seeds = seeds))
  })

  # 2. Evaluate on fresh trials
  pv_test <- list(protocol = pvals_for("test", "protocol"), pocock = pvals_for("test", "pocock"))
  res <- rbindlist(lapply(seq_len(nrow(sc)), function(i) {
    best <- best_run(runs[[i]])
    r <- with(sc[i], evaluate_scenario(rule, spending, S, as_graph(best), pv_test, pv_test$protocol))
    r[, tag := sc$tag[i]]
    r[, seed_best := best$seed]
    r[, train_gain_spread := diff(range(vapply(runs[[i]], function(x) x$train_gain, 1)))]
    r
  }))
  graphs <- rbindlist(lapply(seq_len(nrow(sc)), function(i) {
    best <- best_run(runs[[i]]); e <- graph_edges_text(as_graph(best))
    data.table(tag = sc$tag[i], rule = sc$rule[i], spending = sc$spending[i], S = sc$S[i],
               seed = best$seed, train_gain = best$train_gain, initial = e$initial, edges = e$edges)
  }))

  # 3. Merge into the running results files
  merge_csv <- function(new, file) {
    if (file.exists(file)) {
      old <- fread(file)
      old <- old[!tag %in% new$tag]
      new <- rbind(old, new, fill = TRUE)
    }
    fwrite(new, file)
  }
  merge_csv(res, result_path("scenarios.csv"))
  merge_csv(graphs, result_path("graphs.csv"))
  list(results = res, graphs = graphs)
}

# Compact print of scenario results
show_results <- function(res) {
  out <- res[, .(rule, spending, S, graph,
                 gain = fmt(gain), se = fmt(se, 3), p_stop = fmt(p_stop, 3),
                 vs_graph = sprintf("%s (%s)", fmt(diff_vs_protocol_graph), fmt(se_graph, 3)),
                 vs_design = sprintf("%s (%s)", fmt(diff_vs_protocol_design), fmt(se_design, 3)),
                 NI_ILI = fmt(pow_NI_ILI, 3), SUP_ILI0 = fmt(pow_SUP_ILI0, 3), NI_SID = fmt(pow_NI_SID, 3),
                 SUP_ILI91 = fmt(pow_SUP_ILI91, 3), SUP_SID0 = fmt(pow_SUP_SID0, 3))]
  print(out, row.names = FALSE)
}
