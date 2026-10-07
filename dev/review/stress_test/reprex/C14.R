# C14: trial_success_gsd() cannot compile a minus sign applied to a negative value
# Run: Rscript C14.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

penalty <- -0.5     # held as a negative number; the gain subtracts it
log <- capture.output(
    g <- tryCatch(trial_success_gsd(r1 + (-!!penalty) * r2, K = 2, verbose = "silent"),
                  error = function(e) conditionMessage(e))
)
if (is.character(g)) {
    cat("trial_success_gsd(r1 + (-!!penalty) * r2):", g, "\n")
    cpp <- grep("total \\+=", log, value = TRUE)[1]
    cat("generated C++:", sub(";.*", "", sub(".*total", "total", cpp)), "\n")
    cat("compiler:", sub(".*error: ", "error: ", grep("error:", log, value = TRUE)[1]), "\n")
} else {
    cat("built; value when both are rejected:", g$func(matrix(1L, 1, 2)), "\n")
}
cat("EXPECTED: built, with value 1.5 when both hypotheses are rejected\n")
