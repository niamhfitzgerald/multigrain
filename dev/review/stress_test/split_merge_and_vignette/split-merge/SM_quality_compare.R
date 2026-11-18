# fmt: skip file
# Compare the two runs of SM_quality.R: main (508d0b7, truncated Cauchy mutation) against split-merge (ff9d907).
# Usage: Rscript SM_quality_compare.R SM_quality_main.rds SM_quality_split-merge.rds
suppressMessages(library(data.table))
a <- readRDS(commandArgs(TRUE)[1])[, build := "main"]
b <- readRDS(commandArgs(TRUE)[2])[, build := "split-merge"]
x <- rbind(a, b)
cat("Each graph scored on the 10,000 trials it was optimised on (reported) and on 100,000 fresh trials (fresh).\n")
cat("Same problems, seeds and trials on both builds; one thread.\n\n")
print(x[, .(runs = .N, mean_fresh = round(mean(fresh), 4), best_fresh = round(max(fresh), 4), worst_fresh = round(min(fresh), 4),
            optimism = round(mean(reported - fresh), 4), mean_seconds = round(mean(seconds))), by = .(problem, build)], row.names = FALSE)
p <- merge(a[, .(problem, seed, main = fresh)], b[, .(problem, seed, sm = fresh)], by = c("problem", "seed"))
cat("\nPaired by seed, split-merge minus main (fresh gain):\n")
print(p[, .(pairs = .N, mean_diff = signif(mean(sm - main), 3), se = signif(sd(sm - main) / sqrt(.N), 3),
            split_merge_better = sum(sm > main)), by = problem], row.names = FALSE)
cat("\nBoth builds are scored on the same fresh trials; se is the standard error of the mean paired difference over seeds.\n")
