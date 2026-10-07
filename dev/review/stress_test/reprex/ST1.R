# ST1: a flat stretch of the boundary table is inverted from its lower end
# Run: Rscript ST1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# The interim may spend up to 0.01 of the level a hypothesis holds; the final gets the rest.
cap <- function(a, t) ifelse(t < 1, pmin(a, 0.01), a)
info <- c(0.5, 1)
level <- 0.39 * 0.025                      # a hypothesis with weight 0.39 at alpha 0.025
cat("level:", level, "  cumulative spend at the two analyses:", cap(level, info), "\n")

# One hypothesis, interim p-value 1, a grid of final p-values.
p2 <- 10^seq(-8, -2, length.out = 20000)
raw <- array(1, dim = c(length(p2), 1, 2))
raw[, 1, 2] <- p2
rp <- transform_pvalues_gsd(raw, info_frac = info, spending = cap)$pvals[, 1, 2]

cat("repeated p-value of a final p-value of 1e-4:", signif(rp[which.min(abs(p2 - 1e-4))], 4), "\n")
thr <- max(c(0, p2[rp < level]))           # largest final p-value rejected at this level
cat("largest final p-value rejected at level", level, ":", signif(thr, 4), "\n")

# Exact type I error: reject at the interim (p1 < level) or at the final (p2 < thr).
z <- qnorm(c(level, thr), lower.tail = FALSE)
rho <- sqrt(info[1] / info[2])
err <- 1 - mvtnorm::pmvnorm(upper = z, corr = matrix(c(1, rho, rho, 1), 2))[1]
cat("exact type I error of the hypothesis:", signif(err, 5),
    "=", round(err / level, 4), "x its level\n")
cat("EXPECTED: no final p-value rejected at this level, since nothing is left to spend;",
    "type I error 0.00975\n")
