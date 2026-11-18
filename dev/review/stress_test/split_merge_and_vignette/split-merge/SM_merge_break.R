# fmt: skip file
# What happens to the group sequential optimiser when split-merge (ff9d907) is merged into gsd-build-spending (31ada01).
# The build is the tree of `git merge-tree --write-tree origin/gsd-build-spending origin/split-merge`; git reports
# conflicts only in .gitignore and NEWS.md, which the package build does not read.
# Run: R_LIBS=<merged build> Rscript SM_merge_break.R
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
try_it <- function(label, expr) cat(sprintf("%-55s %s\n", label, tryCatch({ force(expr); "ran" },
    error = function(e) paste("ERROR:", gsub("\\s+", " ", paste(conditionMessage(e), collapse = " "))))))
corr <- matrix(c(1, 0.5, 0.5, 1), 2)
set.seed(1)
raw  <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = corr, info_frac = c(0.5, 1), nsim = 2000)
pv   <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 64L)
spec <- transform_pvalues_gsd(raw, spending = list(gsDesign::sfLDOF, sf_hsd_opt(bounds = c(-4, 1), step = 0.5)), grid_size = 64L)
gain <- trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75))
try_it("graph_optimise_gsd(), fixed spending, global search", graph_optimise_gsd(pv, graph_constraint_free(2), gain))
try_it("graph_optimise_gsd(), joint spending search", graph_optimise_gsd(spec, graph_constraint_free(2), gain))
try_it("graph_optimise_gsd(), fixed spending, global_search = FALSE", graph_optimise_gsd(pv, graph_constraint_free(2), gain, global_search = FALSE))
p_fs <- simulate_pvalues(c(0.9, 0.8, 0.7), corr_matrix = diag(3), nsim = 2000)
try_it("graph_optimise(), fixed sample", graph_optimise(p_fs, graph_constraint_free(3), trial_success(r1 + r2 + r3)))
cat("exists .make_cauchy_mutation_multi():", exists(".make_cauchy_mutation_multi", envir = asNamespace("multigrain")), "\n")
g <- multigrain:::default_control()$global_opt
cat("default_control(): pcrossover", g$pcrossover, " pmutation", g$pmutation, "(31ada01 alone: 0.2 and 0.8)\n")
cat("EXPECTED: every call runs; the group sequential searches keep a mutation that exists\n")
