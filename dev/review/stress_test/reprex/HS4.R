# HS4: the spending parameter cannot be optimised on its own (fixed graph, or one hypothesis)
# Run: Rscript HS4.R   (needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
set.seed(1)
raw  <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = diag(2), info_frac = c(0.5, 1), nsim = 2000)
spec <- transform_pvalues_gsd(raw, spending = list(gsDesign::sfLDOF, sf_hsd_opt(bounds = c(-4, 1), step = 0.5)), grid_size = 64L)
gain <- trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75))
fixed <- tryCatch(graph_constraint(hyp_constraint = c(0.5, 0.5), trans_constraint = matrix(c(0, 1, 1, 0), 2)),
                  error = function(e) e)
msg <- if (inherits(fixed, "error")) conditionMessage(fixed) else tryCatch({
    graph_optimise_gsd(pvals = spec, graph_constraint = fixed, trial_success = gain); "ran" },
    error = function(e) conditionMessage(e))
cat("graph fixed, gamma free:", gsub("\\s+", " ", paste(msg, collapse = " ")), "\n")
cat("one hypothesis:         ", tryCatch({ graph_constraint_free(1); "ran" },
    error = function(e) gsub("\\s+", " ", conditionMessage(e))), "\n")
# the way round it: resolve each node and score the fixed graph
nodes <- seq(-4, 1, by = 1)
g <- vapply(nodes, function(v) calc_power_pvals_gsd(resolve_pvalues_gsd(spec, v), hyp_weight = c(0.5, 0.5),
            trans_matrix = matrix(c(0, 1, 1, 0), 2), custom_power = list(gain = gain))$gain, numeric(1))
cat("workaround, gain at gamma =", paste0(nodes, ": ", round(g, 4), collapse = ", "), "\n")
cat("EXPECTED: graph_optimise_gsd() returns the best gamma for the fixed graph\n")
