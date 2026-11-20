# Try the DS1 fix in a session: DS1_fix.R is put in place of the three lines of transform_pvalues_gsd() that read the
# attribute, and the patched function is run on the calls of reprex/DS1.R and on four other cases.
# Usage, from this folder: Rscript DS1_fix_test.R
# fmt: skip file
suppressMessages(library(multigrain))
ns <- asNamespace("multigrain")
src <- deparse(get("transform_pvalues_gsd", ns), width.cutoff = 500)
hook <- grep("if (is.null(info_frac)) {", src, fixed = TRUE)
stopifnot(length(hook) == 1, trimws(src[hook + 1]) == 'info_frac <- attr(pvals, "info_frac")', trimws(src[hook + 2]) == "}")
src <- c(src[seq_len(hook - 1)], readLines("DS1_fix.R"), src[-seq_len(hook + 2)])
g <- eval(parse(text = src)); environment(g) <- ns
utils::assignInNamespace("transform_pvalues_gsd", g, ns = "multigrain")
tpg <- get("transform_pvalues_gsd", ns)             # the patched function
pocock <- function(a, t) gsDesign::sfLDPocock(a, t)$spend
show <- function(label, expr) cat(sprintf("%-52s %s\n", label, tryCatch({ expr; "accepted" },
                                  error = function(e) paste("error:", gsub("\\s+", " ", conditionMessage(e))))))
set.seed(1)
raw <- simulate_pvalues_gsd(0.025, info_frac = c(0.2, 1), nsim = 2e5)
show("reprex/DS1.R, info_frac left out:", tpg(raw, spending = pocock))
show("reprex/DS1.R, info_frac = c(0.8, 1):", tpg(raw, info_frac = c(0.8, 1), spending = pocock))
show("reprex/DS1.R, info_frac = c(0.1, 1):", tpg(raw, info_frac = c(0.1, 1), spending = pocock))
set.seed(1)
raw2 <- simulate_pvalues_gsd(c(0.025, 0.025), info_frac = rbind(c(0.2, 1), c(NA, 1)), nsim = 100)
show("matrix attribute, the same info_frac given:", tpg(raw2, info_frac = rbind(c(0.2, 1), c(NA, 1)), spending = pocock))
show("matrix attribute, a vector given (the NA differs):", tpg(raw2, info_frac = c(0.2, 1), spending = pocock))
noattr <- raw2; attr(noattr, "info_frac") <- NULL
show("no attribute, info_frac given:", tpg(noattr, info_frac = c(0.8, 1), spending = pocock))
cat("EXPECTED: the three calls whose info_frac differs from the attribute are refused; the other three are accepted\n")
