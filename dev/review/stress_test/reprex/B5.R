# B5: a string objective of trial_success() is pasted into C++ unchecked
# Run: Rscript B5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- rbind(c(TRUE, TRUE), c(TRUE, FALSE), c(FALSE, TRUE), c(FALSE, FALSE))

g <- trial_success("abs(r1 - 0.5) + r2", verbose = "silent")
cat("abs(r1 - 0.5) + r2 on the four rejection patterns\n")
cat("  compiled gain:", g$func(x), "\n")
cat("  plain R      :", mean(abs(x[, 1] - 0.5) + x[, 2]), "\n")

# Any C function can be called from a string, including system().
# The shell command appends a line to a file in the working directory.
setwd(tempdir())
g2 <- trial_success("r1 + r2 + 0 * system(\"echo ran >> B5_marker.txt\")",
                    verbose = "silent")
invisible(g2$func(x))
cat("system() in a string objective ran", length(readLines("B5_marker.txt")),
    "times for", nrow(x), "simulated trials\n")
cat("EXPECTED: both strings refused, as the same text typed as an expression is\n")
