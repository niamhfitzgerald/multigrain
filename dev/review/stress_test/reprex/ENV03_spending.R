# ENV03 (spending list): a spending list named in another order is applied by position
# Run: Rscript ENV03_spending.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8, 0.7), info_frac = c(0.5, 1), nsim = 1000)

# Meant: Pocock-type spending for H3, O'Brien-Fleming type for H1 and H2.
spending <- list(H3 = sfLDPocock, H1 = sfLDOF, H2 = sfLDOF)
pv <- transform_pvalues_gsd(raw, spending = spending)

s <- capture.output(summary(pv))
cat(s[grep("^ *hypothesis", s) + 0:3], sep = "\n")
interim <- sapply(pv$tables, function(tab) tab$bounds[nrow(tab$bounds), 1])
cat("interim nominal boundary at the full level, H1 H2 H3:", round(interim, 5), "\n")
cat("EXPECTED: 0.00153 0.00153 0.0155 (matched by name), or an error that the names",
    "are in another order\n")
