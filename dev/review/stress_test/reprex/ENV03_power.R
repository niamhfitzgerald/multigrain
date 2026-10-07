# ENV03_power: hypothesis names are ignored; a graph named in another order is evaluated as a different graph
# Run: Rscript ENV03_power.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 20000)
colnames(pvals) <- c("OS", "PFS", "ORR")

w <- c(OS = 0.6, PFS = 0.3, ORR = 0.1)
G <- rbind(OS  = c(OS = 0,   PFS = 0.7, ORR = 0.3),
           PFS = c(OS = 0.4, PFS = 0,   ORR = 0.6),
           ORR = c(OS = 0.5, PFS = 0.5, ORR = 0))
cat("columns of pvals:               ", colnames(pvals), "\n")
cat("graph written as OS, PFS, ORR:  ", calc_power_pvals(pvals, w, G)$local_power, "\n")

ord <- c("ORR", "OS", "PFS")          # the same graph, written in another order
cat("graph written as ORR, OS, PFS:  ", calc_power_pvals(pvals, w[ord], G[ord, ord])$local_power, "\n")
cat("EXPECTED: the first line of numbers again (matched by name), or an error that the names disagree\n")
