# UT2: a gsDesign spending function with a required parameter fails with R's own error
# Run: Rscript UT2.R   (needs a gsd-build or gsd-build-spending build of multigrain, and gsDesign)
# fmt: skip file
library(multigrain)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 500)
for (sf in c("sfHSD", "sfPower", "sfExponential")) {
    msg <- tryCatch({
        transform_pvalues_gsd(raw, spending = getExportedValue("gsDesign", sf), grid_size = 64L)
        "accepted"
    }, error = function(e) gsub("\\s+", " ", conditionMessage(e)))
    cat(sprintf("spending = gsDesign::%-14s %s\n", sf, msg))
}
ok <- tryCatch({
    transform_pvalues_gsd(raw, spending = function(a, t) gsDesign::sfHSD(a, t, param = -4), grid_size = 64L)
    "accepted"
}, error = function(e) conditionMessage(e))
cat("the wrapped form, function(a, t) gsDesign::sfHSD(a, t, param = -4):", ok, "\n")
cat("EXPECTED: a message that names the hypothesis and shows the wrapped form\n")
