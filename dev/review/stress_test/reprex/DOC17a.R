# DOC17a: the result name of a single custom_power measure is not documented
# Run: Rscript DOC17a.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8), nsim = 500)
out <- calc_power_pvals(pvals, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2),
                        custom_power = function(x) x[1] && x[2])
cat("names of the result:", names(out), "\n")

rd <- tools::Rd_db("multigrain")[["calc_power_pvals.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("^custom_power:", txt)
cat("?calc_power_pvals on a single measure:", txt[i:(i + 3)], sep = "\n")
cat("EXPECTED: the help says that a single measure is reported as `custom_power`\n")
