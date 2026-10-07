# C6: an error inside a spending function surfaces without the hypothesis it belongs to
# Run: Rscript C6.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- array(runif(60), dim = c(10, 3, 2))       # 3 hypotheses, 2 analyses
spending <- list(sfLDOF, sfLDPocock, sfHSD)      # sfHSD needs a parameter, which is not given
msg <- tryCatch(
    {
        transform_pvalues_gsd(raw, info_frac = c(0.5, 1), spending = spending)
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("transform_pvalues_gsd() says:\n", msg, "\n")
cat("EXPECTED: an error that names hypothesis 3 and says that its spending function failed\n")
