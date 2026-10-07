# C16: trial_success() cannot build a gain with a constant that R prints in exponent form, or a negative one
# Run: Rscript C16.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 1. A constant that R prints in exponent form (100000 or 0.0001, for example; 123456 builds)
log <- capture.output(
    big <- tryCatch({ trial_success(100000 * r1 + r2, verbose = "silent"); "built" },
                    error = function(e) conditionMessage(e))
)
cat("trial_success(100000 * r1 + r2):", big, "\n")
cpp <- grep("total \\+=", log, value = TRUE)
if (length(cpp) > 0) cat("  generated C++:", sub(";.*", "", sub(".*total", "total", cpp[1])), "\n")

# 2. A negative constant, typed or injected
penalty <- -0.5
neg <- tryCatch({ trial_success(r1 + !!penalty * r2, verbose = "silent"); "built" },
                error = function(e) conditionMessage(e))
cat("trial_success(r1 + !!penalty * r2), penalty = -0.5:", neg, "\n")
cat("EXPECTED: both gains are built\n")
