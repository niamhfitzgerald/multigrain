# DS3: a gain that is 0/0 in some trials compiles without a word; power is NaN and the optimisers stop inside GA or nloptr
# Run: Rscript DS3.R   (about 10 s)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
said <- function(expr) tryCatch(withCallingHandlers(expr, warning = function(w) {
    cat("  warning:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }),
    error = function(e) cat("  error:", gsub("\\s+", " ", conditionMessage(e)), "\n"))
G <- matrix(c(0, 1, 1, 0), 2)
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.6), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), info_frac = c(0.5, 1), nsim = 4000)
pv <- transform_pvalues_gsd(raw, spending = function(a, t) gsDesign::sfLDOF(a, t)$spend)
gain <- trial_success_gsd(r1 / t1 + r2 / t2)     # "worth 1/k if rejected at analysis k"; 0/0 when not rejected
cat("calc_power_pvals_gsd(), gain:", calc_power_pvals_gsd(pv, c(0.5, 0.5), G, custom_power = list(g = gain))$g, "\n")
cat("graph_optimise_gsd():\n");                        set.seed(2); said(graph_optimise_gsd(pv, graph_constraint_free(2), gain))
cat("graph_optimise_gsd(global_search = FALSE):\n");   set.seed(2); said(graph_optimise_gsd(pv, graph_constraint_free(2), gain, global_search = FALSE))
p <- simulate_pvalues(c(0.9, 0.6), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), nsim = 4000)
cat("graph_optimise() with trial_success(r1 / (r1 + r2)):\n")
set.seed(2); said(graph_optimise(p, graph_constraint_free(2), trial_success = trial_success(r1 / (r1 + r2))))
cat("EXPECTED: an error from multigrain that the gain is not a number in some trials, for example when H1 is not rejected\n")
