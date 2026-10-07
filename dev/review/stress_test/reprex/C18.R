# C18: a discount table that the gain never applies is accepted without a word
# Run: Rscript C18.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Meant: a rejection at the second analysis is worth 80% of one at the first.
# Written with r1, r2 where d(t1), d(t2) were needed.
g <- trial_success_gsd(r1 + r2, d = c(1, 0.8), verbose = "silent")
print(g)

early <- matrix(1L, 1, 2)    # both hypotheses rejected at analysis 1
late  <- matrix(2L, 1, 2)    # both rejected at analysis 2
cat("gain, both rejected at analysis 1:", g$func(early), "\n")
cat("gain, both rejected at analysis 2:", g$func(late), " (1.6 if the table were applied)\n")
cat("EXPECTED: a warning that discount table `d` is not used in the objective\n")
