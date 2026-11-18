# HS2: the plateau tolerance is a fixed 5e-4 in gain units, whatever the gain's scale or the simulation error
# Run: Rscript HS2.R   (about 3 minutes; needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
corr <- matrix(c(1, 0.5, 0.5, 1), 2)
set.seed(2)
raw  <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8), corr_matrix = corr, info_frac = c(0.5, 1), nsim = 20000)
spec <- transform_pvalues_gsd(raw, spending = list(gsDesign::sfLDOF, sf_hsd_opt(bounds = c(-4, 1), step = 0.5)), grid_size = 128L)
gains <- list("x 1"    = trial_success_gsd(r1 * d(t1) + r2 * d(t2), d = c(1, 0.75)),
              "x 100"  = trial_success_gsd(100 * r1 * d(t1) + 100 * r2 * d(t2), d = c(1, 0.75)),
              "x 0.01" = trial_success_gsd(0.01 * r1 * d(t1) + 0.01 * r2 * d(t2), d = c(1, 0.75)))
for (k in names(gains)) {
    set.seed(7)
    res <- graph_optimise_gsd(pvals = spec, graph_constraint = graph_constraint_free(2), trial_success = gains[[k]], num_threads = 2)
    se  <- res$spending_profile$se
    cat(sprintf("gain %-6s gamma* %-4s|%s\n", k, res$spending_param,
                sub("^ +", " ", grep("within 5e-4", capture.output(print(res)), value = TRUE))))
    cat(sprintf("             5e-4 is %.3g times the median standard error of the differences\n", 5e-4 / median(se[se > 0])))
}
cat("EXPECTED: the same plateau at every scale, for example the run of values with diff <= 2 * se\n")
