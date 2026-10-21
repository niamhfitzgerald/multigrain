# FAM2: with families, the nodes are labelled H1, H2, ... although each node is a family
# Run: Rscript FAM2.R   (needs the family-opt build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))

set.seed(5)
S <- matrix(0.4, 5, 5); diag(S) <- 1
P <- simulate_pvalues(c(0.9, 0.8, 0.8, 0.7, 0.6), corr_matrix = S, nsim = 3000)
fs <- family_spec(list(primary = 1, secondary = 2:4, other = 5))
gain <- trial_success(2 * r1 + (r2 && r3 && r4) + 0.5 * r5, verbose = "silent")
fit <- graph_optimise(P, graph_constraint_free(3), gain, families = fs, verbose = "silent")

cat("names of the weights      :", names(fit$hyp_weight), "\n")
cat("names of family_power     :", names(fit$power$family_power), "\n")
cat("node H2 is the family     :", names(fs$members)[2], "= hypotheses", fs$members[[2]], "\n")
cat("EXPECTED: nodes named after the families (primary, secondary, other) in the result, print() and plot()\n")
