# C5: first-analysis repeated p-values are wrong for raw p-values below about 1e-15
# Run: Rscript C5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.1, 1)
p1 <- c(1e-25, 1e-20, 1e-17, 1e-12)        # first-analysis p-values; the final ones are 0.5
raw <- array(c(p1, rep(0.5, 4)), dim = c(4, 1, 2))
got <- transform_pvalues_gsd(raw, info_frac = info, spending = sfLDOF)$pvals[, 1, 1]

# At the first analysis the boundary is the spend itself, so the exact value has a closed form.
exact <- 2 * pnorm(qnorm(p1 / 2, lower.tail = FALSE) * sqrt(info[1]), lower.tail = FALSE)
print(signif(cbind(raw_p = p1, repeated_p = got, exact = exact, ratio = got / exact), 3))

cat("sfLDOF(0.005, 0.1)$spend:", sfLDOF(0.005, 0.1)$spend, " exact spend:",
    2 * pnorm(qnorm(0.0025, lower.tail = FALSE) / sqrt(0.1), lower.tail = FALSE), "\n")
cat("EXPECTED: ratio 1 in every row\n")
