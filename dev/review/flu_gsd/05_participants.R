# How many more participants per arm the protocol design would need to match
# an optimised design. The protocol design (protocol graph, protocol spending,
# protocol stopping rule) is re-simulated at larger sample sizes on fresh
# trials and its gain matched to the target by bisection.
# Run from this folder: Rscript 05_participants.R
source("00_setup.R")

S <- 2
sc <- fread(result_path("scenarios.csv"))
targets <- list()
pick <- function(label, rule_, spending_, S_, graph_ = "optimised") {
  r <- sc[rule == rule_ & spending == spending_ & S == S_ & graph == graph_]
  if (nrow(r)) targets[[label]] <<- r$gain[1]
}
pick("Continue regardless, optimised graph", "none", "protocol", S)
pick("Protocol rule, Pocock, optimised graph", "protocol", "pocock", S)
pick("Alternative rule, Pocock, optimised graph", "alt", "pocock", S)
gf <- list.files(result_path(), "^gamma__protocol__S2.00.csv$", full.names = TRUE)
if (length(gf)) {
  g <- fread(gf[1]); targets[["Protocol rule, optimised graph and gamma"]] <- g[which.max(gain), gain]
}

gain_protocol_design <- function(n_arm) {
  z <- simulate_z(1e5, test_seed, n_arm = n_arm)
  pv <- make_pvals(z, spending_set("protocol"))
  score_graph(pv, protocol_graph, S, "protocol")$gain
}
base <- gain_protocol_design(trial$n_arm)
cat(sprintf("Protocol design at %d per arm: %.3f\n", trial$n_arm, base))

match_n <- function(target, lo = trial$n_arm, hi = 2L * trial$n_arm, tol = 25L) {
  g_hi <- gain_protocol_design(hi)
  if (g_hi < target) return(c(n = NA, gain = g_hi))
  while (hi - lo > tol) {
    mid <- as.integer(round((lo + hi) / 2))
    if (gain_protocol_design(mid) < target) lo <- mid else hi <- mid
  }
  c(n = hi, gain = gain_protocol_design(hi))
}

out <- rbindlist(lapply(names(targets), function(nm) {
  r <- match_n(targets[[nm]])
  data.table(design = nm, target_gain = targets[[nm]], protocol_gain_at_n0 = base,
             n_match = r[["n"]], extra_per_arm = r[["n"]] - trial$n_arm, gain_at_match = r[["gain"]])
}))
fwrite(out, result_path("participants.csv"))
print(out, row.names = FALSE)
