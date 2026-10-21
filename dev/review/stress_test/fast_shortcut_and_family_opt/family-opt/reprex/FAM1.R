# FAM1: a missing p-value in a family changes the other members' adjusted p-values,
# and the hypothesis with no p-value can be rejected
# Run: Rscript FAM1.R   (needs the family-opt build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
show <- function(p, members, tst, label) {
    fs <- family_spec(c(list(members), as.list(setdiff(seq_len(ncol(p)), members))), test = tst)
    adj <- multigrain:::.prepare_pvals(p, fs)
    M <- length(fs$members); G <- matrix(1 / max(M - 1, 1), M, M); diag(G) <- 0
    rej <- multigrain:::graph_shortcut_families(adj, multigrain:::family_spec_get_index(fs) - 1L,
                                                 0.025, c(1, rep(0, M - 1)), G)
    cat(sprintf("%-8s %-24s adjusted %-22s rejected %s\n", tst, label,
                paste(format(adj[1, members], digits = 3), collapse = " "), paste(which(rej[1, ]), collapse = " ")))
}
# A family of two, {H1, H2}, plus H3 on its own
for (tst in c("hommel", "holm")) {
    show(rbind(c(0.001, NA, 0.5)), 1:2, tst, "H2 missing")
    show(rbind(c(NA, 0.001, 0.5)), 1:2, tst, "H1 missing")
}
# A family of three, {H1, H2, H3}, plus H4 on its own
for (tst in c("hommel", "hochberg", "holm")) {
    show(rbind(c(NA, 0.001, 0.002, 0.5)), 1:3, tst, "H1 missing (of 3)")
    show(rbind(c(0.001, 0.002, NA, 0.5)), 1:3, tst, "H3 missing (of 3)")
}
cat("p.adjust(c(NA, 0.001, 0.002), \"hommel\"):", format(p.adjust(c(NA, 0.001, 0.002), "hommel")), "\n")

# The optimiser accepts the same input with no message
set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000); P[1:100, 1] <- NA
fit <- graph_optimise(P, graph_constraint_free(2), trial_success(r1 + r2 + r3, verbose = "silent"),
                      families = family_spec(list(1:2, 3)), verbose = "silent")
cat("graph_optimise() with 100 missing p-values of H1: returns weights", round(fit$hyp_weight, 3),
    "and power of H1", round(fit$power$local_power[1], 3), "(no message)\n")
cat("EXPECTED: an error naming the missing p-value; a hypothesis with no p-value is never rejected\n")
