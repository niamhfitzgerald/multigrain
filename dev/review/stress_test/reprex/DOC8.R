# DOC8: data-raw/graph_optimal_example.R no longer rebuilds the bundled dataset
# Run from the repository root: Rscript DOC8.R   (needs the gsd-build build; about 20 seconds)
# fmt: skip file
library(multigrain)

cran_cores <- function() 2L      # the script takes this helper from tests/testthat
src <- readLines("data-raw/graph_optimal_example.R")
src <- src[seq_len(grep("^usethis::use_data", src) - 1)]          # all but the save
src <- sub('verbose = "detail"', 'verbose = "silent"', src, fixed = TRUE)
eval(parse(text = src))          # runs the script: seeds, p-values, graph_optimise()

stored <- multigrain::graph_optimal_example
rebuilt <- graph_optimal_example
show <- function(x) sprintf("gain %.7f  source %-6s  H1->H2 %.4f  H2->H1 %.4f",
    x$power$trial_success, x$solution$opt_source, x$trans_matrix[1, 2], x$trans_matrix[2, 1])
cat("bundled dataset:", show(stored), "\n")
cat("script output  :", show(rebuilt), "\n")
cat("same transition matrix:", isTRUE(all.equal(stored$trans_matrix, rebuilt$trans_matrix)), "\n")
cat("EXPECTED: TRUE, and the same gain and source, since the script fixes every seed\n")
