# B9: a saved gain, and so a saved optimisation result, cannot be used after reloading
# Run: Rscript B9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

g <- trial_success(r1 + 0.5 * r2, verbose = "silent")
file <- tempfile(fileext = ".rds")
saveRDS(g, file)
g_reloaded <- readRDS(file)      # as in a later session, or on another machine

set.seed(1)
p <- simulate_pvalues(c(0.9, 0.8), nsim = 10000)
w <- c(0.5, 0.5)
G <- rbind(c(0, 1), c(1, 0))
cat("gain before saving  :", calc_power_pvals(p, w, G, custom_power = g)$custom_power, "\n")
after <- tryCatch(
    format(calc_power_pvals(p, w, G, custom_power = g_reloaded)$custom_power),
    error = function(e) paste("ERROR:", conditionMessage(e))
)
cat("gain after reloading:", after, "\n")
cat("C++ source still held by the reloaded object:", nchar(g_reloaded$cpp_code), "characters\n")
cat("EXPECTED: the same value after reloading, or a message saying how to rebuild the gain\n")
