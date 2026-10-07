# ENV05: with a negative `scipen` option no gain can be built
# Run: Rscript ENV05.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

options(scipen = -5)     # a session set to print numbers in scientific notation
log <- capture.output(
    msg <- tryCatch({ trial_success(r1 + 2 * r2, verbose = "silent"); "built" },
                    error = function(e) conditionMessage(e))
)
options(scipen = 0)

cat("trial_success(r1 + 2 * r2) under options(scipen = -5):", msg, "\n")
cat("compiler output printed to the console:", length(log), "lines\n")
cat("generated C++ lines the compiler rejects:\n")
cat(sprintf("  %s\n", trimws(sub(" *//.*", "", grep("e\\+00", log, value = TRUE)))), sep = "")
cat("EXPECTED: the gain is built; `scipen` only controls how R prints numbers\n")
