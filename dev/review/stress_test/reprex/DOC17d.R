# DOC17d: normalise_sum() does not check fixed_idx against the length of x
# Run: Rscript DOC17d.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- c(0.2, 0.3, 0.6)
cat("no fixed element:", normalise_sum(x), "\n")

beyond <- tryCatch(normalise_sum(x, fixed_idx = 7L), error = function(e) conditionMessage(e))
cat("fixed_idx = 7L:  ", beyond, "\n")

negative <- tryCatch(normalise_sum(x, fixed_idx = -1L), error = function(e) conditionMessage(e))
cat("fixed_idx = -1L: ", negative, "\n")
cat("EXPECTED: an error naming `fixed_idx` in both cases: positions run from 1 to 3\n")
