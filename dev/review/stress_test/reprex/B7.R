# B7 (with MEM2): a num_threads of 65,537 or more ends the R session
# Run: Rscript B7.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# The call that crashes is made in a child process, so this session survives.
code <- 'library(multigrain)
set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 500)
ctrl <- multigrain_control() |>
    control_global(maxiter = 2, run = 2, popSize = 10) |>
    control_local(maxeval = 10)
res <- graph_optimise(pvals, graph_constraint_free(3),
                      trial_success(r1 + r2 + r3, verbose = "silent"),
                      num_threads = %d, control = ctrl, verbose = "silent")
cat("finished\n")'

run <- function(threads) {
    system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(sprintf(code, threads))),
            stdout = FALSE, stderr = FALSE)
}
cat("cores on this machine:", parallel::detectCores(), "\n")
cat("num_threads = 65536: child exit status", run(65536L), "\n")
cat("num_threads = 65537: child exit status", run(65537L), "(139 = segmentation fault)\n")
cat("EXPECTED: exit status 0 for both, with the request capped at the number of cores, or an R error\n")
