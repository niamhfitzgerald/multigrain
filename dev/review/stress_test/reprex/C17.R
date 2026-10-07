# C17: a mistyped hypothesis index is accepted, however large
# Run: Rscript C17.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# r100001 for r1 (a slip of the keyboard). Only the gap warning is caught here,
# so nothing is compiled.
start <- Sys.time()
warned <- tryCatch(trial_success(r100001 + r2, verbose = "silent"),
                   warning = function(w) conditionMessage(w))
cat("seconds until the constructor says anything:",
    round(as.numeric(Sys.time() - start, units = "secs"), 1), "\n")
cat("it is a warning of", nchar(warned), "characters, beginning:\n ", substr(warned, 1, 90), "\n")
cat("EXPECTED: an immediate error for an index no design can have\n")
