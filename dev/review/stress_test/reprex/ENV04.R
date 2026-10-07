# ENV04: a local search on all rows depends on the session seed, and changes it
# Run: Rscript ENV04.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(3)
P <- simulate_pvalues(c(0.85, 0.8, 0.6), nsim = 3000)
gain <- trial_success(0.3 * r1 + 0.7 * r2 + 0.3 * (r2 && r3), verbose = "silent")

# No global search and nsim_local unset: every row is used and nothing in the search is random.
for (seed in 1:3) {
    set.seed(seed)
    before <- .Random.seed
    res <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent")
    cat("set.seed(", seed, "): weights ", paste(sprintf("%.4f", res$hyp_weight), collapse = " "),
        "  gain ", sprintf("%.6f", res$power$trial_success),
        "  .Random.seed ", if (identical(before, .Random.seed)) "unchanged" else "changed", "\n", sep = "")
}
cat("EXPECTED: three identical lines, and .Random.seed unchanged\n")
