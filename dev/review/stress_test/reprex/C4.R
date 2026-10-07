# C4: grid_size is accepted down to 2, where the type I error is above the level
# Run: Rscript C4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(1, 2, 3) / 3
level <- 0.2 * 0.025                       # a hypothesis with weight 0.2 at alpha 0.025
p <- 10^seq(-8, -1.6, length.out = 50000)  # the same grid of raw p-values at every analysis
raw <- array(rep(p, 3), dim = c(length(p), 1, 3))

for (grid_size in c(2, 8, 64, 1024)) {
    pv <- transform_pvalues_gsd(raw, info_frac = info, spending = sfLDPocock, grid_size = grid_size)
    # largest raw p-value rejected at each analysis, then the exact crossing probability
    thr <- apply(pv$pvals[, 1, ], 2, function(x) max(p[x < level]))
    b <- qnorm(thr, lower.tail = FALSE)
    err <- sum(gsProbability(k = 3, theta = 0, n.I = info, a = rep(-20, 3), b = b)$upper$prob)
    cat(sprintf("grid_size %4d: exact type I error %.6f = %.3f x the level\n",
                grid_size, err, err / level))
}
cat("EXPECTED: a grid_size that puts the type I error above the level is refused\n")
