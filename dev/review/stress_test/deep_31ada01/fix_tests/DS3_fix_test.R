# Try the DS3 fix in a session: DS3_fix.R is put in place of the last line of the two objective closures. A valid gain
# is optimised before and after the change, then the entry's script is run with the patched optimisers.
# Usage, from this folder: Rscript DS3_fix_test.R ../../reprex/DS3.R
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain.verbosity = "silent")
ns <- asNamespace("multigrain")
set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.6), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), info_frac = c(0.5, 1), nsim = 4000)
pv <- transform_pvalues_gsd(raw, spending = function(a, t) gsDesign::sfLDOF(a, t)$spend)
p <- simulate_pvalues(c(0.9, 0.6), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), nsim = 4000)
valid <- function() {
    set.seed(2); a <- get("graph_optimise_gsd", ns)(pv, graph_constraint_free(2), trial_success_gsd(r1 + r2))
    set.seed(2); b <- get("graph_optimise", ns)(p, graph_constraint_free(2), trial_success = trial_success(r1 + r2))
    lapply(list(gsd = a, fixed = b), function(o) list(o$hyp_weight, o$trans_matrix, o$power$trial_success))
}
before <- valid()
fix <- readLines("DS3_fix.R")
patch <- function(fname, from) {
    src <- deparse(get(fname, ns), width.cutoff = 500)
    hit <- which(trimws(src) == from); stopifnot(length(hit) == 1)
    src <- c(src[seq_len(hit - 1)], gsub("res$time", sub("power_criterion\\((.*)\\)", "\\1", from), fix, fixed = TRUE), src[-seq_len(hit)])
    g <- eval(parse(text = src)); environment(g) <- ns; utils::assignInNamespace(fname, g, ns = "multigrain")
}
patch("create_obj_func_gsd", "power_criterion(res$time)")
patch("create_obj_func", "power_criterion(rej_matrix)")
after <- valid()
cat(sprintf("valid gain r1 + r2: weights, transition matrix and gain the same before and after the change: group sequential %s, fixed sample %s\n",
            identical(before$gsd, after$gsd), identical(before$fixed, after$fixed)))
cat(sprintf("  (group sequential: weights %s, gain %.4f)\n", paste(signif(after$gsd[[1]], 6), collapse = " "), after$gsd[[3]]))
# the exported optimisers are called through the namespace so that they see the patched closures
graph_optimise <- get("graph_optimise", ns); graph_optimise_gsd <- get("graph_optimise_gsd", ns)
src <- readLines(commandArgs(TRUE)[1]); src <- src[!grepl("^suppressMessages\\(library\\(multigrain\\)\\)", src)]
eval(parse(text = src))
cat("EXPECTED: the same graph before and after, then multigrain's message in place of the three GA and nloptr errors\n")
