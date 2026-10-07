# D_global_output: result$global_output is an invalid S4 object and cannot be printed
# Run: Rscript D_global_output.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 1000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")

ga <- res$global_output            # documented as "Output from the genetic algorithm"
cat("class:", class(ga), "  has its `call` slot:", methods::.hasSlot(ga, "call"), "\n")

msg <- tryCatch({
    utils::capture.output(print(ga))
    "printed"
}, error = function(e) conditionMessage(e))
cat("print(res$global_output):", msg, "\n")
cat("EXPECTED: a valid `ga` object that prints\n")
