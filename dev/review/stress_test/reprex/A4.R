# A4: sum_to_one_constraint = FALSE switches off the row-sum check altogether
# Run: Rscript A4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(1, 0, 0)
G <- rbind(c(0, 1, 1),   # H1 passes all its alpha to H2, and all of it again to H3
           c(0, 0, 0),
           c(0, 0, 0))
cat("row sums of the transition matrix:", rowSums(G), "\n")
cat("is_graph_valid(sum_to_one_constraint = FALSE):",
    is_graph_valid(w, G, sum_to_one_constraint = FALSE), "\n")

set.seed(1)
pvals <- simulate_pvalues(c(0.9999, 0.025, 0.025), nsim = 2e5)   # H2 and H3 are true nulls
out <- calc_power_pvals(pvals, w, G, sum_to_one_constraint = FALSE,
                        custom_power = list(any_null = function(x) x[2] || x[3]))
cat("P(reject a true null) at one-sided alpha 0.025:", round(out$any_null, 4), "\n")
cat("EXPECTED: FALSE with a warning, then an error from calc_power_pvals(): row 1 sums to 2\n")
