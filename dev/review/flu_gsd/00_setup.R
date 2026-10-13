# Shared set-up for the flu vaccine GSD optimisation. Sourced by the numbered
# scripts in this folder. Needs multigrain from the gsd-build branch, and
# config_local.R (copy config_template.R and fill it in; it is git-ignored).
#
# Value model (agreed 13 Oct): per-claim timing. Each endpoint is worth the
# highest level it reaches (ILI 10 / 15 / 20, SID 10 / 15). A level reached at
# the interim is worth S times its value, whether or not the trial stops. A
# trial that stops at the interim keeps only the levels reached there.

suppressPackageStartupMessages({
  library(multigrain)
  library(data.table)
  library(mvtnorm)
  library(ggplot2)
})

# Run every script from this folder: cd dev/review/flu_gsd && Rscript 01_...R
.flu_dir <- getwd()
if (!file.exists(file.path(.flu_dir, "config_local.R"))) {
  stop("config_local.R not found in ", .flu_dir, ". Copy config_template.R and fill it in.")
}
source(file.path(.flu_dir, "config_local.R"))
for (d in c("runs", "results")) dir.create(file.path(.flu_dir, d), showWarnings = FALSE)
run_path <- function(...) file.path(.flu_dir, "runs", ...)
result_path <- function(...) file.path(.flu_dir, "results", ...)

alpha <- trial$alpha
hyp   <- copy(trial$hyp)[, margin := log(margin_rr)]
ids   <- hyp$id
m     <- nrow(hyp)
t_info <- c(trial$at_risk[[1]] / sum(trial$at_risk), 1)   # interim, final

## Trials: Wald Z on log RR against each margin, from binomial counts ---------
# Returns Z at the end of season 1 (z1) and pooled over both seasons (z2).
simulate_z <- function(nsim, seed, n_arm = trial$n_arm, at_risk = trial$at_risk,
                       ve = trial$ve) {
  set.seed(seed)
  a  <- round(n_arm * at_risk)
  z1 <- z2 <- matrix(NA_real_, nsim, m, dimnames = list(NULL, ids))
  wald <- function(xv, xc, nn) {                  # 0.5 guards against a zero count
    xv <- pmax(xv, 0.5); xc <- pmax(xc, 0.5)
    list(lrr = log(xv / xc), se = sqrt(1 / xv - 1 / nn + 1 / xc - 1 / nn))
  }
  for (ep in c("ILI", "SID")) {
    pc <- trial$attack[[ep]]; pv <- pc * (1 - ve[[ep]])
    xc1 <- rbinom(nsim, a[[1]], pc); xv1 <- rbinom(nsim, a[[1]], pv)
    xc2 <- xc1 + rbinom(nsim, a[[2]], pc); xv2 <- xv1 + rbinom(nsim, a[[2]], pv)
    s1 <- wald(xv1, xc1, a[[1]]); s2 <- wald(xv2, xc2, sum(a))
    for (j in which(hyp$endpoint == ep)) {
      z1[, j] <- (hyp$margin[j] - s1$lrr) / s1$se
      z2[, j] <- (hyp$margin[j] - s2$lrr) / s2$se
    }
  }
  list(z1 = z1, z2 = z2)
}

## Spending functions ---------------------------------------------------------
sf_named <- function(code) switch(code, POC = gsDesign::sfLDPocock, OBF = gsDesign::sfLDOF,
                                  stop("unknown spending code ", code))
hsd <- function(gamma) { force(gamma); function(alpha, t) gsDesign::sfHSD(alpha, t, gamma) }

# spending_set("protocol"): as in the protocol (config). spending_set("pocock"):
# Lan-DeMets Pocock for every hypothesis. spending_set(gamma = g): one
# Hwang-Shih-DeCani gamma shared by every hypothesis, or a vector of m gammas.
spending_set <- function(name = c("protocol", "pocock"), gamma = NULL) {
  if (!is.null(gamma)) {
    gamma <- rep_len(gamma, m)
    return(lapply(gamma, hsd))
  }
  name <- match.arg(name)
  if (name == "protocol") return(lapply(hyp$spend, sf_named))
  rep(list(gsDesign::sfLDPocock), m)
}

make_pvals <- function(z, spending) {
  raw <- array(NA_real_, c(nrow(z$z1), m, 2L))
  raw[, , 1] <- pnorm(z$z1, lower.tail = FALSE)
  raw[, , 2] <- pnorm(z$z2, lower.tail = FALSE)
  transform_pvalues_gsd(raw, info_frac = t_info, spending = spending, alpha = alpha)
}

## Stopping rules ---------------------------------------------------------------
# expr: the rule in multigrain's gain grammar on season-1 decision times.
# fun:  the same rule on a logical matrix of season-1 rejections.
stop_rules <- list(
  none = list(
    label = "Continue regardless", expr = NULL,
    fun = function(R1) rep(FALSE, nrow(R1))),
  protocol = list(
    label = "Protocol: NI_ILI, SUP_ILI0 and NI_SID",
    expr = "((t1 == 1) && (t2 == 1) && (t3 == 1))",
    fun = function(R1) R1[, "NI_ILI"] & R1[, "SUP_ILI0"] & R1[, "NI_SID"]),
  alt = list(
    label = "Alternative: NI_ILI and (SUP_ILI0 or NI_SID)",
    expr = "((t1 == 1) && ((t2 == 1) || (t3 == 1)))",
    fun = function(R1) R1[, "NI_ILI"] & (R1[, "SUP_ILI0"] | R1[, "NI_SID"]))
)

## Gains ------------------------------------------------------------------------
# Highest-level values. R(i) is "H_i rejected": r_i by season 2, (t_i == 1) at
# season 1. Hypotheses: 1 NI_ILI, 2 SUP_ILI0, 3 NI_SID, 4 SUP_ILI91, 5 SUP_SID0.
levels_expr <- function(R) sprintf(
  "(10 * (%s || %s || %s) + 5 * (%s || %s) + 5 * %s + 10 * (%s || %s) + 5 * %s)",
  R(1), R(2), R(4), R(2), R(4), R(4), R(3), R(5), R(5))
by_s2 <- function(i) paste0("r", i)
at_s1 <- function(i) sprintf("(t%d == 1)", i)
value_max <- 35

# Per-claim timing: value = L(by season 2) + (S - 1) * L(at season 1), which is
# S * L(at season 1) + [levels added at season 2]. With a stopping rule a
# stopped trial keeps only S * L(at season 1).
gain_expr <- function(S, rule = "none") {
  timed <- sprintf("(%s + %g * %s)", levels_expr(by_s2), S - 1, levels_expr(at_s1))
  s <- stop_rules[[rule]]$expr
  if (is.null(s)) return(timed)
  sprintf("%s * %g * %s + (1 - %s) * %s", s, S, levels_expr(at_s1), s, timed)
}
make_gain <- function(S, rule = "none") {
  trial_success_gsd(!!gain_expr(S, rule), K = 2, verbose = "silent")
}

# The same value, per trial, from a matrix of decision times (0 never, 1 or 2)
levels_value <- function(R) {
  10 * (R[, 1] | R[, 2] | R[, 4]) + 5 * (R[, 2] | R[, 4]) + 5 * R[, 4] +
    10 * (R[, 3] | R[, 5]) + 5 * R[, 5]
}
trial_values <- function(times, S, rule = "none") {
  R1 <- times == 1L; colnames(R1) <- ids
  R2 <- times > 0L
  stop <- stop_rules[[rule]]$fun(R1)
  L1 <- levels_value(R1); L2 <- levels_value(R2)
  R_final <- R2; R_final[stop, ] <- R1[stop, ]   # a stopped trial keeps season-1 rejections only
  list(value = ifelse(stop, S * L1, L2 + (S - 1) * L1), stop = stop, R1 = R1, R2 = R_final)
}

## Graphs -------------------------------------------------------------------------
make_graph <- function(edges, w0) {
  G <- matrix(0, m, m, dimnames = list(ids, ids))
  for (e in edges) G[e[1], e[2]] <- as.numeric(e[3])
  list(w = w0, G = G)
}
protocol_graph <- make_graph(trial$protocol_edges, trial$protocol_w0)
constraint_alpha_on_ni_ili <- graph_constraint(hyp_constraint = c(1, 0, 0, 0, 0), names = ids)

graph_edges_text <- function(g, digits = 3) {
  G <- round(unname(g$G), digits); w <- round(g$w, digits)
  e <- which(G > 5 * 10^-(digits + 1), arr.ind = TRUE)
  e <- e[order(e[, 1], -G[e]), , drop = FALSE]
  list(initial = paste(sprintf("%s %.*f", ids[w > 0], digits, w[w > 0]), collapse = "; "),
       edges = paste(sprintf("%s -> %s %.*f", ids[e[, 1]], ids[e[, 2]], digits, G[e]), collapse = "; "))
}

## Decision times and scoring -------------------------------------------------------
decision_times <- function(pv, g) {
  res <- multigrain:::graph_shortcut_gsd(
    pvals = multigrain:::.gsd_kernel_matrix(pv), alpha = alpha,
    w = as.numeric(g$w), G = unname(g$G), K = pv$K)
  res$time
}

# Scores a graph on a p-value set under the value model (S, rule). Returns the
# mean gain, its Monte Carlo SE, the stopping probability, power by hypothesis
# under the rule (a stopped trial rejects nothing at season 2) and at season 1,
# and the per-trial values for paired comparisons.
score_graph <- function(pv, g, S, rule = "none") {
  tv <- trial_values(decision_times(pv, g), S, rule)
  list(gain = mean(tv$value), se = sd(tv$value) / sqrt(length(tv$value)),
       p_stop = mean(tv$stop),
       power = setNames(colMeans(tv$R2), ids), power_s1 = setNames(colMeans(tv$R1), ids),
       per_trial = tv$value)
}
paired <- function(a, b) c(diff = mean(a - b), se = sd(a - b) / sqrt(length(a)))

## Optimiser (resumable) ---------------------------------------------------------------
n_threads <- as.integer(Sys.getenv("FLU_THREADS", "2"))
train_seed <- 20251208L
test_seed  <- 1L
optim_seeds <- c(11L, 22L)
ctrl <- control_nsim_global(multigrain_control(), 2e4)

# One optimiser run per seed, saved to runs/<tag>__s<seed>.rds; skipped if the
# file exists. Returns the saved results (one per seed).
optimise_graph <- function(pv_train, gain, tag, seeds = optim_seeds, start_graph = NULL) {
  lapply(seeds, function(seed) {
    f <- run_path(sprintf("%s__s%d.rds", tag, seed))
    if (file.exists(f)) return(readRDS(f))
    t0 <- Sys.time(); set.seed(seed)
    args <- list(pv_train, constraint_alpha_on_ni_ili, gain, num_threads = n_threads,
                 control = ctrl, verbose = "silent")
    if (!is.null(start_graph)) args$start_graph <- start_graph
    res <- do.call(graph_optimise_gsd, args)
    out <- list(tag = tag, seed = seed, hyp_weight = res$hyp_weight, trans_matrix = res$trans_matrix,
                train_gain = res$power[[length(res$power)]],
                minutes = as.numeric(difftime(Sys.time(), t0, units = "mins")))
    saveRDS(out, f)
    cat(sprintf("%s  %-40s seed %d  train gain %.4f  (%.1f min)\n",
                format(Sys.time(), "%H:%M"), tag, seed, out$train_gain, out$minutes))
    out
  })
}
best_run <- function(runs) runs[[which.max(vapply(runs, function(r) r$train_gain, 1))]]
as_graph <- function(run) list(w = as.numeric(run$hyp_weight), G = unname(run$trans_matrix))

## Scenario bookkeeping ------------------------------------------------------------------
# A scenario is a stopping rule, a spending set and a value S.
scenario_tag <- function(rule, spending, S) sprintf("%s__%s__S%.2f", rule, spending, S)

# Evaluates protocol and optimised graphs for one scenario on the test trials.
# pv_test_list: named list of test p-value sets by spending name.
evaluate_scenario <- function(rule, spending, S, g_opt, pv_test_list, pv_protocol_design) {
  pv <- pv_test_list[[spending]]
  prot <- score_graph(pv, protocol_graph, S, rule)
  opt  <- score_graph(pv, g_opt, S, rule)
  # The protocol design: protocol graph, protocol spending, protocol stopping rule, same S
  pdes <- score_graph(pv_protocol_design, protocol_graph, S, "protocol")
  d_graph  <- paired(opt$per_trial, prot$per_trial)
  d_design <- paired(opt$per_trial, pdes$per_trial)
  row <- function(what, s) data.table(
    rule = rule, spending = spending, S = S, graph = what,
    gain = s$gain, se = s$se, p_stop = s$p_stop,
    as.data.table(as.list(setNames(s$power, paste0("pow_", ids)))),
    as.data.table(as.list(setNames(s$power_s1, paste0("s1_", ids)))))
  rbind(
    cbind(row("protocol", prot), diff_vs_protocol_graph = 0, se_graph = 0,
          diff_vs_protocol_design = paired(prot$per_trial, pdes$per_trial)[["diff"]],
          se_design = paired(prot$per_trial, pdes$per_trial)[["se"]]),
    cbind(row("optimised", opt), diff_vs_protocol_graph = d_graph[["diff"]], se_graph = d_graph[["se"]],
          diff_vs_protocol_design = d_design[["diff"]], se_design = d_design[["se"]])
  )
}

fmt <- function(x, d = 2) formatC(x, format = "f", digits = d)
