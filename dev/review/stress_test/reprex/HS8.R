# HS8: sf_hsd_opt() prints as a bare function with attributes
# Run: Rscript HS8.R   (needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
out <- capture.output(print(sf_hsd_opt(id = "secondary", bounds = c(-4, -2), step = 0.5)))
cat("lines printed:", length(out), "\n")
cat(head(out, 4), sep = "\n")
cat("EXPECTED: one line, e.g. <sf_hsd_opt> secondary: Hwang-Shih-DeCani spending, parameter in [-4, -2], step 0.5 (5 nodes)\n")
