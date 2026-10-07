# MEM3: a kernel call cannot be interrupted (Ctrl-C or Esc waits until it has finished)
# Run: Rscript MEM3.R   (needs the gsd-build build of multigrain; Linux or macOS, uses `kill`)
# fmt: skip file
library(multigrain)

m <- 64                                   # a wide design: about m^3 operations per trial
set.seed(1)
pvals <- matrix(runif(10000 * m) * 1e-6, 10000, m)     # every hypothesis is rejected
w <- rep(1 / m, m)
G <- matrix(1 / (m - 1), m, m)
diag(G) <- 0

full <- system.time(calc_power_pvals(pvals, w, G))[["elapsed"]]
cat("one uninterrupted call takes", round(full, 1), "s\n")

# the same call again, with an interrupt (what Ctrl-C sends) after 0.5 s
system(sprintf("(sleep 0.5; kill -INT %d) &", Sys.getpid()))
start <- Sys.time()
finished <- FALSE
invisible(tryCatch({
    calc_power_pvals(pvals, w, G)
    finished <- TRUE
    Sys.sleep(2)                          # R acts on a pending interrupt here at the latest
}, interrupt = function(e) NULL))
stopped <- as.numeric(difftime(Sys.time(), start, units = "secs"))
cat("interrupt sent at 0.5 s, acted on at", round(stopped, 1), "s\n")
cat("the call ran to its end before the interrupt was seen:", finished, "\n")
cat("EXPECTED: the call abandoned shortly after 0.5 s (FALSE in the line above)\n")
