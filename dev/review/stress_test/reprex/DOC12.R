# DOC12: the error for `r1 + r2 && r3` does not say that parentheses are needed
# Run: Rscript DOC12.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Meant: r1 + (r2 && r3). R reads it as (r1 + r2) && r3.
msg <- tryCatch(trial_success_gsd(r1 + r2 && r3, K = 2, verbose = "silent"),
                error = function(e) conditionMessage(e))
cat("error message:\n")
cat(msg, "\n")
cat("mentions parentheses:", grepl("parenthes", msg), "\n")
cat("EXPECTED: a message that says how R grouped the expression and where to put parentheses\n")
