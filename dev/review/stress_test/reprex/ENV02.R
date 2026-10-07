# ENV02: gains built at the same moment in forked workers fail at random
# Run: Rscript ENV02.R   (needs the gsd-build build of multigrain; Unix only, since it forks)
# fmt: skip file
library(multigrain)

x <- rbind(c(TRUE, FALSE), c(TRUE, TRUE))   # the mean of k * r1 + r2 on x is k + 0.5

# A sweep over a weight k: one gain per scenario, each built in its own worker
out <- suppressWarnings(parallel::mclapply(1:8, function(k) {
    g <- trial_success(!!k * r1 + r2, verbose = "silent")
    g$func(x)
}, mc.cores = 8, mc.preschedule = FALSE))

failed <- vapply(out, inherits, logical(1), what = "try-error")
cat("workers that failed:", sum(failed), "of 8\n")
cat(sprintf("  %s\n", unique(trimws(unlist(out[failed])))), sep = "")
cat("values from the others:", unlist(out[!failed]), "\n")
cat("(a race between the workers: the count varies from run to run)\n")
cat("EXPECTED: 0 of 8 failed and the values 1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5\n")
