# DOC10: the help example of calc_power_pvals() calls a sum of rejections "average_power"
# Run: Rscript DOC10.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
example(calc_power_pvals, echo = FALSE)    # runs the help example; leaves `result`

cat("average_power in the help example:", result$average_power, "\n")
cat("expected number of rejections:    ", result$exp_rejections, "\n")
cat("mean of the three local powers:   ", mean(result$local_power), "\n")
cat("EXPECTED: average_power equal to the mean of the local powers, a number between 0 and 1\n")
