# A3: index 0 is accepted in a gain and reads outside the matrix
# Run: Rscript A3.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

g <- trial_success(r0 + r1 + r2, verbose = "silent")
cat("hypotheses the object says it covers:", g$m, "\n")
cat("generated C++:", grep("total \\+=", strsplit(g$cpp_code, "\n")[[1]], value = TRUE), "\n")

rej <- matrix(c(TRUE, TRUE, FALSE, TRUE), 2, 2)   # r1 + r2 has mean 1.5 here
val <- g$func(rej)
cat("value of r0 + r1 + r2:", format(val), "\n")
cat("plausible (between 1.5 and 2.5):", val >= 1.5 && val <= 2.5, "\n")

# The group sequential constructor accepts t0 too; using it ends the R session,
# so the call is made in a child process.
code <- 'library(multigrain)
g <- trial_success_gsd(d(t0) + d(t1) + d(t2), d = c(1, 0.8), verbose = "silent")
g$func(matrix(1L, 100000, 2))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with d(t0): exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an error from both constructors, since hypotheses are numbered from 1\n")
