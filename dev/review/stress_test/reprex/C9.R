# C9: hypothesis names are not validated, and plot() fails after the optimisation
# Run: Rscript C9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 1000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
pdf(NULL)

# A name typed twice
msg <- tryCatch({
    con <- graph_constraint(c(NA, NA, NA), names = c("PFS", "PFS", "OS"))
    cat("graph_constraint(): accepted\n")
    res <- graph_optimise(P, con, gain, global_search = FALSE, verbose = "silent")
    cat("graph_optimise(): ran, gain", res$power$trial_success, "\n")
    suppressWarnings(plot(res))
    "no error"
}, error = function(e) conditionMessage(e))
cat("stopped with:", msg, "\n")

# The documented default, passed explicitly
msg <- tryCatch({
    con <- graph_constraint(c(NA, NA, NA), names = "auto")
    paste("accepted, names", paste(names(con$hyp_constraint), collapse = " "))
}, error = function(e) conditionMessage(e))
cat('names = "auto":', msg, "\n")
cat("EXPECTED: the repeated name refused by graph_constraint(); \"auto\" accepted as H1 H2 H3\n")
