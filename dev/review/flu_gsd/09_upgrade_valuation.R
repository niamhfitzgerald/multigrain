# Further analysis 1: how to value an endpoint that upgrades between seasons.
#
#   increments (the round-2 model): each step up an endpoint's ladder is valued
#     at the time it is reached. NI ILI at season 1 then SUP ILI 0% at season 2
#     is worth 10 x S + 5.
#   best: the endpoint is worth its single best claim, max over levels of
#     value x timing. The same trial is worth max(10 x S, 15).
#
# Part 1 scores every fixed design in the library under both models at
# S = 1, 1.5, 2 (S = 1 is the same under both). Part 2 re-optimises graph and
# shared gamma inside multigrain under the "best" model (protocol rule,
# S = 1.5 and 2), to see whether the chosen design changes.
# Run from this folder: Rscript 09_upgrade_valuation.R
source("00_setup.R"); source("design_library.R")

z_test <- simulate_z(1e5, test_seed)
tms <- library_times(z_test)
std_tm <- standard_times(z_test)

## Part 1: every fixed design under both models --------------------------------
# every graph-and-spending pair in the library, under every stopping rule
xd <- cross_designs()
grid <- CJ(S = c(1, 1.5, 2), model = c("increments", "best"))
part1 <- rbindlist(lapply(seq_len(nrow(grid)), function(i) {
  S <- grid$S[i]; model <- grid$model[i]
  std <- trial_value(std_tm, "none", S, model = model)$value
  rows <- rbindlist(lapply(names(xd), function(nm) {
    d <- xd[[nm]]; tv <- trial_value(tms[[d$base]], d$rule, S, model = model)
    data.table(design = nm, base = d$base, round = d$round, rule = d$rule, spend_key = d$spend_key,
               tuned_for = d$tuned_for, value = mean(tv$value), p_stop = mean(tv$stop),
               diff_vs_standard = mean(tv$value - std), se_diff = sd(tv$value - std) / sqrt(length(std)))
  }))
  rbind(rows, data.table(design = "standard", round = 0, rule = "standard", spend_key = "-", tuned_for = "",
                         value = mean(std), p_stop = 0, diff_vs_standard = 0, se_diff = 0), fill = TRUE)[
    , `:=`(S = S, model = model)]
}))
pd <- part1[design == "r2|protocol|protocol|protocol graph || rule=protocol", .(S, model, protocol_design = value)]
part1 <- merge(part1, pd, by = c("S", "model"))
part1[, diff_vs_protocol_design := value - protocol_design]
fwrite(part1, result_path("upgrade_valuation_all_designs.csv"))

# Best design for each stopping rule, under each model and S
best_by_rule <- part1[, .SD[which.max(value)], by = .(S, model, rule)][order(S, model, -value)]
fwrite(best_by_rule, result_path("upgrade_valuation_best_by_rule.csv"))
cat("\nBest design for each stopping rule (value; gain over protocol design)\n")
print(dcast(best_by_rule[, .(rule, key = paste(model, S), value = round(value, 2))], rule ~ key, value.var = "value"), row.names = FALSE)
cat("\nBest design overall, by model and S\n")
print(part1[, .SD[which.max(value)], by = .(S, model)][, .(S, model, design, value = round(value, 2),
      vs_protocol_design = round(diff_vs_protocol_design, 2), p_stop = round(p_stop, 3))], row.names = FALSE)

## Part 2: re-optimise graph and shared gamma under the "best" model ---------------
# max(a, b) for non-negative a, b, written in multigrain's gain grammar
max2 <- function(a, b) sprintf("(%s * (%s >= %s) + %s * (%s > %s))", a, a, b, b, b, a)
best_gain_expr <- function(S, rule = "protocol") {
  ep_value <- function(ep, stopped) {
    terms <- vapply(level_def[[ep]], function(lv) {
      at1 <- sprintf("(%s)", paste(sprintf("(t%d == 1)", lv$h), collapse = " || "))
      by2 <- sprintf("(%s)", paste(sprintf("r%d", lv$h), collapse = " || "))
      M <- if (stopped) sprintf("%g * %s", S, at1) else sprintf("(%s + %g * %s)", by2, S - 1, at1)
      sprintf("(%g * %s)", lv$v, M)
    }, "")
    Reduce(max2, terms)
  }
  total <- function(stopped) sprintf("(%s + %s)", ep_value("ILI", stopped), ep_value("SID", stopped))
  s <- stop_rules[[rule]]$expr
  if (is.null(s)) return(total(FALSE))
  sprintf("%s * %s + (1 - %s) * %s", s, total(TRUE), s, total(FALSE))
}
make_best_gain <- function(S, rule = "protocol") trial_success_gsd(!!best_gain_expr(S, rule), K = 2, verbose = "silent")

# Check the compiled gain against the R scorer on the protocol design
pv_prot <- make_pvals(z_test, spending_set("protocol"))
for (S in c(1.5, 2)) {
  mg <- calc_power_pvals_gsd(pv_prot, protocol_graph$w, unname(protocol_graph$G),
                             custom_power = list(g = make_best_gain(S)), sum_to_one_constraint = FALSE)$g
  r <- mean(trial_value(decision_times(pv_prot, protocol_graph), "protocol", S, model = "best")$value)
  cat(sprintf("Check, best model, S = %g: compiled %.5f, R %.5f\n", S, mg, r))
  stopifnot(abs(mg - r) < 1e-9)
}

gammas <- c(-4, -3, -2, -1, 0, 0.5, 1)
cands  <- setNames(lapply(gammas, hsd), sprintf("g%+.1f", gammas))
raw_array <- function(z) {
  raw <- array(NA_real_, c(nrow(z$z1), m, 2L))
  raw[, , 1] <- pnorm(z$z1, lower.tail = FALSE); raw[, , 2] <- pnorm(z$z2, lower.tail = FALSE)
  raw
}
z_train <- simulate_z(1e5, train_seed)
bank_train <- spending_bank_gsd(raw_array(z_train), info_frac = t_info, spending = cands, alpha = alpha)

part2 <- rbindlist(lapply(c(1.5, 2), function(Sv) {
  tag <- sprintf("bestmodel__protocol__S%.2f__shared", Sv)
  runs <- lapply(optim_seeds, function(seed) {
    f <- run_path(sprintf("%s__s%d.rds", tag, seed))
    if (file.exists(f)) return(readRDS(f))
    t0 <- Sys.time(); set.seed(seed)
    res <- graph_optimise_gsd(bank_train, constraint_alpha_on_ni_ili, make_best_gain(Sv), spending_shared = TRUE,
                              num_threads = n_threads, control = ctrl, verbose = "silent")
    out <- list(tag = tag, seed = seed, hyp_weight = res$hyp_weight, trans_matrix = res$trans_matrix,
                gamma = gammas[res$spending$index], train_gain = res$power[[length(res$power)]],
                minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")))
    saveRDS(out, f)
    cat(sprintf("%s  %-36s seed %d  gamma %s  train gain %.4f  (%.1f min)\n", format(Sys.time(), "%H:%M"),
                tag, seed, paste(unique(out$gamma), collapse = " "), out$train_gain, out$minutes))
    out
  })
  best <- best_run(runs); g <- as_graph(best)
  tm <- decision_times(make_pvals(z_test, spending_set(gamma = best$gamma)), g)
  v_best <- trial_value(tm, "protocol", Sv, model = "best")
  v_incr <- trial_value(tm, "protocol", Sv, model = "increments")
  # the increments-model design at the same S, scored under the best model
  inc_design <- part1[model == "best" & S == Sv & design %like% sprintf("^r2\\|protocol\\|gamma .*shared for S=%g \\|\\| rule=protocol$", Sv)]
  pdes_best <- part1[model == "best" & S == Sv & design == "r2|protocol|protocol|protocol graph || rule=protocol", value]
  e <- graph_edges_text(g)
  data.table(S = Sv, gamma = best$gamma[1], value_best_model = mean(v_best$value), se = sd(v_best$value) / sqrt(1e5),
             p_stop = mean(v_best$stop), value_under_increments = mean(v_incr$value),
             increments_design_under_best = inc_design$value, increments_design = inc_design$design,
             protocol_design_under_best = pdes_best,
             gain_vs_protocol_design = mean(v_best$value) - pdes_best,
             train_spread = diff(range(vapply(runs, function(r) r$train_gain, 1))),
             initial = e$initial, edges = e$edges)
}))
fwrite(part2, result_path("upgrade_valuation_reoptimised.csv"))
cat("\nRe-optimised under the best-single-claim model (protocol rule)\n")
print(part2[, .(S, gamma, value_best_model = round(value_best_model, 2), se = round(se, 3), p_stop = round(p_stop, 3),
                increments_design_under_best = round(increments_design_under_best, 2),
                protocol_design_under_best = round(protocol_design_under_best, 2),
                gain_vs_protocol_design = round(gain_vs_protocol_design, 2), train_spread = round(train_spread, 3))],
      row.names = FALSE)

## Part 3: break-even S against the standard design, under both models -----------
S_grid <- seq(1, 2, by = 0.005)
tm_prot <- tms[["r2|protocol|protocol|protocol graph"]]
std <- mean(trial_value(std_tm, "none")$value)
be <- rbindlist(lapply(c("increments", "best"), function(model) {
  v <- sapply(S_grid, function(S) mean(trial_value(tm_prot, "protocol", S, model = model)$value))
  data.table(model = model, design = "protocol design", break_even_S = S_grid[which(v >= std)[1]])
}))
fwrite(be, result_path("upgrade_valuation_break_even.csv"))
cat("\nBreak-even S of the protocol design against the standard design\n"); print(be, row.names = FALSE)
