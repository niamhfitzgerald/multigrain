# C7: the tolerance of a graph constraint is not carried into the optimiser
# Run: Rscript C7.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

# weights typed to three decimals, accepted because of the tolerance
con <- graph_constraint(c(0.333, 0.333, 0.333), tolerance = 0.01)
cat("constraint accepted: fixed weights sum to", sum(con$hyp_constraint),
    "with tolerance", attr(con, "tolerance"), "\n")

msg <- tryCatch(
    graph_optimise(P, con, gain, verbose = "silent"),
    error = function(e) conditionMessage(e)
)
cat("graph_optimise():", msg, "\n")
cat("EXPECTED: a search within the stored tolerance, or an error that names the tolerance\n")
