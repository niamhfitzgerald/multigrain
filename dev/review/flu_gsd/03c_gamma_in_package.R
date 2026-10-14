# Task 5, done inside multigrain. The Hwang-Shih-DeCani gamma is chosen by
# graph_optimise_gsd() alongside the graph, from a bank of candidate spending
# functions (spending_bank_gsd(), on branch flu-gsd-optimisation). One gamma
# shared by all hypotheses (spending_shared = TRUE) and one per hypothesis
# (spending_shared = FALSE), for the protocol and alternative stopping rules
# at S = 1, 1.5 and 2. Candidates: gamma = -4, -3, -2, -1, 0, 0.5, 1
# (-4 is close to O'Brien-Fleming, 1 to Pocock; Alex's regulatory range).
# Run from this folder: Rscript 03c_gamma_in_package.R [rules] [S values]
#   e.g. Rscript 03c_gamma_in_package.R protocol,alt 1,1.5,2
source("00_setup.R"); source("run_scenarios.R")

args <- commandArgs(trailingOnly = TRUE)
rules    <- if (length(args) >= 1) strsplit(args[1], ",")[[1]] else c("protocol", "alt")
S_values <- if (length(args) >= 2) as.numeric(strsplit(args[2], ",")[[1]]) else c(1, 1.5, 2)
gammas   <- c(-4, -3, -2, -1, 0, 0.5, 1)
cands    <- setNames(lapply(gammas, hsd), sprintf("g%+.1f", gammas))

raw_array <- function(z) {
  raw <- array(NA_real_, c(nrow(z$z1), m, 2L))
  raw[, , 1] <- pnorm(z$z1, lower.tail = FALSE)
  raw[, , 2] <- pnorm(z$z2, lower.tail = FALSE)
  raw
}
if (is.null(z_train)) z_train <- simulate_z(1e5, train_seed)
if (is.null(z_test))  z_test  <- simulate_z(1e5, test_seed)
cat("Building the spending bank on the training trials...\n")
bank_train <- spending_bank_gsd(raw_array(z_train), info_frac = t_info, spending = cands, alpha = alpha)
bank_test  <- spending_bank_gsd(raw_array(z_test),  info_frac = t_info, spending = cands, alpha = alpha)
pv_protocol_test <- pvals_for("test", "protocol")

# One optimiser run per seed with the bank (resumable); saves the graph and
# the chosen gammas.
optimise_with_bank <- function(gain, tag, shared, seeds = optim_seeds) {
  lapply(seeds, function(seed) {
    f <- run_path(sprintf("%s__s%d.rds", tag, seed))
    if (file.exists(f)) return(readRDS(f))
    t0 <- Sys.time(); set.seed(seed)
    res <- graph_optimise_gsd(bank_train, constraint_alpha_on_ni_ili, gain, spending_shared = shared,
                              num_threads = n_threads, control = ctrl, verbose = "silent")
    out <- list(tag = tag, seed = seed, hyp_weight = res$hyp_weight, trans_matrix = res$trans_matrix,
                gamma = gammas[res$spending$index], label = unname(res$spending$label),
                train_gain = res$power[[length(res$power)]],
                minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")))
    saveRDS(out, f)
    cat(sprintf("%s  %-36s seed %d  gammas %s  train gain %.4f  (%.1f min)\n",
                format(Sys.time(), "%H:%M"), tag, seed, paste(out$gamma, collapse = " "), out$train_gain, out$minutes))
    out
  })
}

sc <- CJ(rule = rules, S = S_values, shared = c(TRUE, FALSE))
res <- rbindlist(lapply(seq_len(nrow(sc)), function(i) {
  rule <- sc$rule[i]; S <- sc$S[i]; shared <- sc$shared[i]
  tag <- sprintf("gammapkg__%s__S%.2f__%s", rule, S, if (shared) "shared" else "perhyp")
  runs <- optimise_with_bank(make_gain(S, rule), tag, shared)
  best <- best_run(runs); g <- as_graph(best)
  choice <- match(best$gamma, gammas)
  pv <- multigrain:::.gsd_assemble_pvals(bank_test, choice)
  opt  <- score_graph(pv, g, S, rule)
  prot <- score_graph(pv, protocol_graph, S, rule)          # protocol graph, chosen gammas
  pdes <- score_graph(pv_protocol_test, protocol_graph, S, "protocol")   # protocol design
  # optimised graph with protocol spending, from the scenario runs (same rule and S)
  scen <- fread(result_path("scenarios.csv"))
  ogps <- scen[rule == sc$rule[i] & spending == "protocol" & S == sc$S[i] & graph == "optimised", gain]
  e <- graph_edges_text(g)
  data.table(rule = rule, S = S, mode = if (shared) "shared" else "per hypothesis",
             seed_best = best$seed, train_gain = best$train_gain,
             train_gain_spread = diff(range(vapply(runs, function(r) r$train_gain, 1))),
             as.data.table(as.list(setNames(best$gamma, paste0("gamma_", ids)))),
             gain = opt$gain, se = opt$se, p_stop = opt$p_stop,
             gain_protocol_graph_same_gamma = prot$gain,
             gain_opt_graph_protocol_spending = if (length(ogps)) ogps[1] else NA_real_,
             diff_vs_protocol_design = paired(opt$per_trial, pdes$per_trial)[["diff"]],
             se_design = paired(opt$per_trial, pdes$per_trial)[["se"]],
             as.data.table(as.list(setNames(opt$power, paste0("pow_", ids)))),
             initial = e$initial, edges = e$edges)
}))
res[, diff_vs_opt_graph_protocol_spending := gain - gain_opt_graph_protocol_spending]

file <- result_path("gamma_in_package.csv")
if (file.exists(file)) {
  old <- fread(file); old <- old[!paste(rule, S, mode) %in% paste(res$rule, res$S, res$mode)]
  res <- rbind(old, res, fill = TRUE)
}
fwrite(res, file)
cat("\nTask 5 inside multigrain: gamma chosen by graph_optimise_gsd()\n")
print(res[order(rule, S, mode), c("rule", "S", "mode", paste0("gamma_", ids), "gain", "se", "p_stop",
                                   "diff_vs_protocol_design", "diff_vs_opt_graph_protocol_spending", "train_gain_spread"), with = FALSE],
      digits = 4, row.names = FALSE)
