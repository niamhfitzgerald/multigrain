# DOC17c: normalise_sum() accepts a negative tolerance
# Run: Rscript DOC17c.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- c(0.25, 0.45, 0.30)                     # the help example: elements 1 and 3 are fixed
cat("default tolerance:", normalise_sum(x, fixed_idx = c(1L, 3L)), "\n")

neg <- tryCatch(normalise_sum(x, fixed_idx = c(1L, 3L), tolerance = -1),
                error = function(e) conditionMessage(e))
cat("tolerance = -1:   ", neg, "\n")
cat("EXPECTED: an error saying that `tolerance` must be at least 0 (the help says \"numeric >= 0\")\n")
