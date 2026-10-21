# SR1: a stopping rule that holds when nothing has been rejected is accepted as an efficacy rule
# Run: Rscript SR1.R   (needs a gsd-build or gsd-build-spending build of multigrain at 8af8adb or later, and gsDesign)
# fmt: skip file
library(multigrain)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8, 0.7), info_frac = c(1/3, 2/3, 1), nsim = 4000)
pv <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
w <- rep(1/3, 3)
G <- (1 - diag(3)) / 2

for (cond in list(NULL, quote(!r1), quote(r1 || TRUE))) {
    lab <- if (is.null(cond)) "no rule" else deparse(cond)
    out <- withCallingHandlers({
        rule <- if (is.null(cond)) NULL else stopping_rule_gsd(!!cond)
        calc_power_pvals_gsd(pv, w, G, stopping_rule = rule)
    }, warning = function(w) {
        cat("  warning:", gsub("\\s+", " ", conditionMessage(w)), "\n")
        invokeRestart("muffleWarning")
    })
    cat(sprintf("%-10s stop at analysis 1, 2, 3: %s   disjunctive power: %.3f\n",
                lab, paste(sprintf("%.3f", out$stop_distribution), collapse = " "), out$disj_power))
}
cat("EXPECTED: a warning (or an error) that `!r1` and `r1 || TRUE` hold with no rejection,\n")
cat("          so they stop trials for futility, not for efficacy\n")
