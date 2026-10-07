# D_power_nominal: the help says "at its final analysis"; the code means "at full information"
# Run: Rscript D_power_nominal.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["simulate_pvalues_gsd.Rd"]]
help_txt <- capture.output(tools::Rd2txt(rd))
i <- grep("power_nominal: ", help_txt)
j <- i + which(help_txt[-seq_len(i)] == "")[1] - 1
cat("?simulate_pvalues_gsd says:", help_txt[i:j], sep = "\n")

set.seed(1)
x <- simulate_pvalues_gsd(0.9, info_frac = c(0.5, 0.8), nsim = 1e5)   # last analysis at 80%
cat("\nsimulated power at the final analysis:", mean(x[, 1, 2] < 0.025), "\n")
cat("power there from the code's model:    ", pnorm(calc_ncp(0.9) * sqrt(0.8) - qnorm(0.975)), "\n")
cat("EXPECTED: help that says 0.9 is the power at an information fraction of 1",
    "(0.83 at this final analysis)\n")
