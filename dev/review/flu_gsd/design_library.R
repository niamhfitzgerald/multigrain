# A library of fixed designs from both rounds, for scoring under different
# value models without re-optimising. Sourced after 00_setup.R.
#
# Each design is a stopping rule, a spending set and a graph. Round-1 designs
# are read from the round-1 run folders (ROUND1_DIR, default
# ../../../../flu_prev relative to this folder, or set the environment
# variable FLU_ROUND1_DIR); they are skipped if absent.

round1_dir <- Sys.getenv("FLU_ROUND1_DIR", "/home/claude/flu_prev")

## Stopping rules on season-1 rejections (logical matrix R1 with ids as names)
all_stop_rules <- list(
  none         = function(R1) rep(FALSE, nrow(R1)),
  protocol     = function(R1) R1[, "NI_ILI"] & R1[, "SUP_ILI0"] & R1[, "NI_SID"],
  alt          = function(R1) R1[, "NI_ILI"] & (R1[, "SUP_ILI0"] | R1[, "NI_SID"]),
  r1           = function(R1) R1[, "NI_ILI"] & (R1[, "SUP_ILI0"] | R1[, "SUP_SID0"]),
  primary_only = function(R1) R1[, "NI_ILI"],
  sup_ili_only = function(R1) R1[, "NI_ILI"] & R1[, "SUP_ILI0"],
  plus_ni_sid  = function(R1) R1[, "NI_ILI"] & R1[, "NI_SID"] & (R1[, "SUP_ILI0"] | R1[, "SUP_SID0"]),
  both_sup     = function(R1) R1[, "NI_ILI"] & R1[, "SUP_ILI0"] & R1[, "SUP_SID0"]
)
rule_names <- c(none = "Continue regardless",
                protocol = "Protocol: NI ILI + SUP ILI 0% + NI SID",
                alt = "Alternative: NI ILI + (SUP ILI 0% or NI SID)",
                r1 = "Round 1: NI ILI + (SUP ILI 0% or SUP SID 0%)",
                primary_only = "NI ILI alone",
                sup_ili_only = "NI ILI + SUP ILI 0%",
                plus_ni_sid = "NI ILI + NI SID + a superiority",
                both_sup = "NI ILI + both superiorities",
                standard = "Standard design (no interim)")

## Spending sets, by key
spend_from_key <- function(key) {
  if (key == "protocol") return(spending_set("protocol"))
  if (key == "pocock")   return(spending_set("pocock"))
  if (key == "obf")      return(rep(list(gsDesign::sfLDOF), m))
  if (startsWith(key, "hsd:")) {
    g <- as.numeric(strsplit(sub("^hsd:", "", key), ",")[[1]])
    return(spending_set(gamma = g))
  }
  stop("unknown spending key ", key)
}
# Share of alpha spent at the interim, averaged over hypotheses
alpha_share_interim <- function(key) {
  sp <- spend_from_key(key)
  mean(vapply(sp, function(f) {
    s <- f(alpha, t_info)
    s <- if (is.list(s)) s$spend else s
    s[1] / alpha
  }, 1))
}

## Library -------------------------------------------------------------------
read_best <- function(files) {
  files <- files[file.exists(files)]
  if (!length(files)) return(NULL)
  r <- lapply(files, readRDS)
  r[[which.max(vapply(r, function(x) x$train_gain, 1))]]
}
lib <- list()
add <- function(name, round, rule, spend_key, graph, tuned_for) {
  if (is.null(graph)) return(invisible())
  lib[[name]] <<- list(name = name, round = round, rule = rule, spend_key = spend_key,
                       graph = list(w = as.numeric(graph$w %||% graph$hyp_weight),
                                    G = unname(graph$G %||% graph$trans_matrix)),
                       tuned_for = tuned_for)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# Round 2: rules none / protocol / alt, spending protocol / pocock
for (rule in c("none", "protocol", "alt")) for (sp in c("protocol", "pocock")) {
  if (rule == "none" && sp == "pocock") next
  add(sprintf("r2|%s|%s|protocol graph", rule, sp), 2, rule, sp, protocol_graph, "")
  for (S in c(1, 1.5, 2)) {
    b <- read_best(run_path(sprintf("%s__s%d.rds", scenario_tag(rule, sp, S), optim_seeds)))
    add(sprintf("r2|%s|%s|graph for S=%g", rule, sp, S), 2, rule, sp, b, sprintf("S=%g", S))
  }
}
# Round 2: graph and gamma chosen inside multigrain
for (rule in c("protocol", "alt")) for (S in c(1, 1.5, 2)) for (mode in c("shared", "perhyp")) {
  b <- read_best(run_path(sprintf("gammapkg__%s__S%.2f__%s__s%d.rds", rule, S, mode, optim_seeds)))
  if (is.null(b)) next
  add(sprintf("r2|%s|gamma %s|%s for S=%g", rule, paste(b$gamma, collapse = ","), mode, S), 2, rule,
      paste0("hsd:", paste(b$gamma, collapse = ",")), b, sprintf("S=%g", S))
}
# Round 1: whole-trial multiplier designs
r1_runs <- file.path(round1_dir, "runs"); r1_extra <- file.path(round1_dir, "runs_extra")
if (dir.exists(r1_extra)) {
  sp_map <- c(protocol = "protocol", all_pocock = "pocock", all_obf = "obf",
              hsd_m4 = "hsd:-4", hsd_m2 = "hsd:-2", hsd_0 = "hsd:0", hsd_1 = "hsd:1")   # hsd_2 is outside [-4, 1]
  for (nm in names(sp_map)) {
    add(sprintf("r1|r1|%s|protocol graph", sp_map[[nm]]), 1, "r1", sp_map[[nm]], protocol_graph, "")
    add(sprintf("r1|r1|%s|graph for F=2", sp_map[[nm]]), 1, "r1", sp_map[[nm]],
        read_best(file.path(r1_extra, sprintf("spending__%s__s11.rds", nm))), "F=2")
  }
  for (mult in c("1.00", "1.50", "2.50", "3.00"))
    add(sprintf("r1|r1|protocol|graph for F=%s", mult), 1, "r1", "protocol",
        read_best(file.path(r1_extra, sprintf("multiplier__x%s__s11.rds", mult))), paste0("F=", mult))
  for (rule in c("primary_only", "sup_ili_only", "plus_ni_sid", "both_sup")) {
    add(sprintf("r1|%s|protocol|protocol graph", rule), 1, rule, "protocol", protocol_graph, "")
    add(sprintf("r1|%s|protocol|graph for F=2", rule), 1, rule, "protocol",
        read_best(file.path(r1_extra, sprintf("stop_rule__%s__s11.rds", rule))), "F=2")
  }
}
if (dir.exists(r1_runs))
  add("r1|r1|protocol|graph for F=2 (main)", 1, "r1", "protocol",
      read_best(file.path(r1_runs, sprintf("alpha_on_NI_ILI__levels_stop_x2__s%d.rds", c(11, 22)))), "F=2")

# Standard design (one analysis at the end of season 2, full alpha)
std_graph <- read_best(run_path(sprintf("standard__levels__s%d.rds", optim_seeds)))

## Scoring -------------------------------------------------------------------
# Decision times for every design on a set of trials, with p-values cached by
# spending key. Returns a list of integer matrices (0 never, 1, 2).
library_times <- function(z, designs = lib) {
  cache <- list()
  lapply(designs, function(d) {
    if (is.null(cache[[d$spend_key]])) cache[[d$spend_key]] <<- make_pvals(z, spend_from_key(d$spend_key))
    decision_times(cache[[d$spend_key]], d$graph)
  })
}
standard_times <- function(z) {
  raw <- array(pnorm(z$z2, lower.tail = FALSE), c(nrow(z$z2), m, 1L))
  pv <- transform_pvalues_gsd(raw, info_frac = 1, spending = gsDesign::sfLDOF, alpha = alpha)
  tm <- decision_times(pv, list(w = as.numeric(std_graph$hyp_weight), G = unname(std_graph$trans_matrix)))
  tm[tm > 0] <- 2L      # its only analysis is at the end of season 2
  tm
}

## Level structure and the two ways of valuing upgrades ------------------------
# Each endpoint is worth the highest level it reaches. Levels (value, the
# hypotheses whose rejection reaches it):
level_def <- list(
  ILI = list(list(v = 10, h = c(1, 2, 4)), list(v = 15, h = c(2, 4)), list(v = 20, h = 4)),
  SID = list(list(v = 10, h = c(3, 5)),    list(v = 15, h = 5))
)
# Time each level is first reached (0 never), after applying the stopping rule
level_times <- function(times, stop) {
  tm <- times; tm[stop & tm == 2L] <- 0L
  tm[tm == 0L] <- 99L
  lapply(level_def, function(ep) lapply(ep, function(lv) {
    out <- do.call(pmin, lapply(lv$h, function(h) tm[, h]))
    out[out == 99L] <- 0L
    out
  }))
}
# Per-trial value. model "increments": each step up an endpoint's ladder is
# valued at the time it is reached (the round-2 model). model "best": the
# endpoint is worth its single best claim, max over levels of value x timing.
# F multiplies the whole value of a trial that stops at season 1.
trial_value <- function(times, rule, S = 1, F = 1, model = c("increments", "best")) {
  model <- match.arg(model)
  R1 <- times == 1L; colnames(R1) <- ids
  stop <- all_stop_rules[[rule]](R1)
  lt <- level_times(times, stop)
  mult <- function(t) ifelse(t == 1L, S, ifelse(t == 2L, 1, 0))
  val <- 0
  for (ep in names(level_def)) {
    v <- vapply(level_def[[ep]], function(lv) lv$v, 1)
    w <- if (model == "increments") diff(c(0, v)) else v
    terms <- lapply(seq_along(v), function(k) mult(lt[[ep]][[k]]) * w[k])
    val <- val + if (model == "increments") Reduce(`+`, terms) else do.call(pmax, terms)
  }
  list(value = val * ifelse(stop, F, 1), stop = stop)
}

# Every graph-and-spending pair in the library under every stopping rule. The
# stopping rule is applied after the procedure has run, so the decision times
# of the base design serve for all rules (look them up with $base).
cross_designs <- function(rules = names(all_stop_rules)) {
  out <- list()
  for (nm in names(lib)) for (r in rules) {
    d <- lib[[nm]]
    out[[sprintf("%s || rule=%s", nm, r)]] <- list(name = sprintf("%s || rule=%s", nm, r), base = nm,
      round = d$round, rule = r, base_rule = d$rule, spend_key = d$spend_key, tuned_for = d$tuned_for)
  }
  out
}
