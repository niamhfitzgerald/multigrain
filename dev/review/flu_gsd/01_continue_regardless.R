# Task 1. Continue regardless: the trial never stops at season 1. Hypotheses
# rejected at the interim keep the value of an early claim (S times their
# value); everything still open is tested at season 2.
# Run from this folder: Rscript 01_continue_regardless.R
source("00_setup.R"); source("run_scenarios.R")

sc <- CJ(rule = "none", spending = "protocol", S = c(1, 1.5, 2))
out <- run_scenarios(sc)

cat("\nTask 1: continue regardless, protocol spending\n")
show_results(out$results)
cat("\nOptimised graphs\n")
print(out$graphs[, .(S, seed, train_gain = fmt(train_gain), initial, edges)], row.names = FALSE)
