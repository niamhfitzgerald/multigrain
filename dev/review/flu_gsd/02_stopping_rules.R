# Tasks 2 to 4. Stopping rules, spending on SUP_SID0 and the value S of an
# early claim.
#   Task 2: protocol rule, stop at season 1 if NI_ILI, SUP_ILI0 and NI_SID are
#           all rejected there.
#   Task 3: alternative rule, stop if NI_ILI and (SUP_ILI0 or NI_SID).
#   Each with the protocol spending (OBF on SUP_SID0) and with Pocock for all.
#   Task 4: both rules and both spending sets at S = 1, 1.5 and 2.
# Run from this folder: Rscript 02_stopping_rules.R [S values]
#   e.g. Rscript 02_stopping_rules.R 2       (tasks 2 and 3 only)
#        Rscript 02_stopping_rules.R 1 1.5 2 (task 4)
source("00_setup.R"); source("run_scenarios.R")

args <- commandArgs(trailingOnly = TRUE)
S_values <- if (length(args)) as.numeric(args) else c(1, 1.5, 2)

sc <- CJ(rule = c("protocol", "alt"), spending = c("protocol", "pocock"), S = S_values)
out <- run_scenarios(sc)

cat("\nTasks 2 to 4: stopping rules\n")
show_results(out$results)
cat("\nOptimised graphs\n")
print(out$graphs[, .(rule, spending, S, seed, train_gain = fmt(train_gain), initial, edges)], row.names = FALSE)
