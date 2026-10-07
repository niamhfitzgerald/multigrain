# A2: calc_power_pvals() evaluates a gain written for more hypotheses than the p-values have
# Run: Rscript A2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)        # 3 hypotheses
gain4 <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")   # written for 4
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2

val <- calc_power_pvals(pvals, w, G, custom_power = list(gain = gain4))$gain
cat("value of r1 + r2 + r3 + r4 on 3 hypotheses:", format(val, big.mark = ","), "\n")
cat("possible (between 0 and 4):", val >= 0 && val <= 4, "\n")

# A gain with a far larger index ends the R session, so the call is made in a
# child process.
code <- 'library(multigrain)
set.seed(1)
pvals <- simulate_pvalues(c(0.8, 0.8), nsim = 2e5)
gain99 <- suppressWarnings(trial_success(r1 + r99, verbose = "silent"))
calc_power_pvals(pvals, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2), custom_power = list(gain = gain99))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with r1 + r99 on 2 hypotheses: exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an error from calc_power_pvals(), since the gain refers to a hypothesis the p-values do not have\n")
