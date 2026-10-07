# C15: trial_success() fails in the C++ compiler on a value taken from a named vector
# Run: Rscript C15.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(pfs = 0.4, os = 0.6)
log <- capture.output(
    g <- tryCatch(trial_success(!!w["pfs"] * r1 + !!w["os"] * r2, verbose = "silent"),
                  error = function(e) conditionMessage(e))
)
if (is.character(g)) {
    cat("trial_success(!!w[\"pfs\"] * r1 + !!w[\"os\"] * r2):", g, "\n")
    cpp <- grep("total \\+=", log, value = TRUE)[1]
    cat("generated C++:", sub(";.*", "", sub(".*total", "total", cpp)), "\n")
    cat("lines of compiler output printed to the console:", length(log), "\n")
} else {
    cat("built; value when both are rejected:", g$func(matrix(TRUE, 1, 2)), "\n")
}
cat("EXPECTED: built, with value 1 when both hypotheses are rejected\n")
