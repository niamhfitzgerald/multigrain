# Trial inputs for the flu vaccine GSD optimisation.
#
# Copy this file to config_local.R (same folder) and fill in the values.
# config_local.R, runs/ and results/ are git-ignored because the trial is
# confidential. Every script sources config_local.R through 00_setup.R.

trial <- list(
  alpha   = 0.025,                          # one-sided
  n_arm   = NA_integer_,                    # randomised per arm
  at_risk = c(season1 = NA, season2 = NA),  # share of each arm still in the trial in each season
  attack  = c(ILI = NA, SID = NA),          # control-arm attack rates, a season
  ve      = c(ILI = NA, SID = NA),          # assumed vaccine efficacy, 1 - relative risk

  # One row per hypothesis, in the order used by the graph.
  # margin_rr: relative risk bound under H0 (1.10 for a 10% NI margin,
  #            1 for superiority, 1 - 0.091 for a 9.1% superiority margin).
  # spend:     "POC" (Lan-DeMets Pocock) or "OBF" (Lan-DeMets O'Brien-Fleming).
  hyp = data.table::data.table(
    id        = c("NI_ILI", "SUP_ILI0", "NI_SID", "SUP_ILI91", "SUP_SID0"),
    endpoint  = c("ILI", "ILI", "SID", "ILI", "SID"),
    margin_rr = c(NA, NA, NA, NA, NA),
    spend     = c(NA, NA, NA, NA, NA)
  ),

  # Protocol graph: initial alpha shares and edges (from, to, weight).
  protocol_w0    = c(NA, NA, NA, NA, NA),
  protocol_edges = list(
    c("NI_ILI", "SUP_ILI0", NA)
  )
)
