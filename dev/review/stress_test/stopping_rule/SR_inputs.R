# fmt: skip file
# What stopping_rule_gsd() and its consumers do with awkward input. Prints the
# outcome of each call (object created, warning, or error message).
suppressMessages(library(multigrain))
try_it <- function(label, expr) {
    out <- tryCatch(withCallingHandlers({ v <- expr; if (inherits(v, "multigrain_stopping_rule_gsd")) paste("created:", paste(v$labels, collapse = " | ")) else if (is.list(v) && !is.null(v$stop_distribution)) paste("ran: stop_distribution =", paste(round(v$stop_distribution, 3), collapse = " ")) else "ran" },
        warning = function(w) { cat(sprintf("%-42s WARNING: %s\n", label, gsub("\\s+", " ", conditionMessage(w)))); invokeRestart("muffleWarning") }),
        error = function(e) paste("ERROR:", gsub("\\s+", " ", conditionMessage(e))))
    cat(sprintf("%-42s %s\n", label, out))
}

cat("== Creating a rule\n")
try_it("r1 & r2 (single &)", stopping_rule_gsd(r1 & r2))
try_it("r1 | r2 (single |)", stopping_rule_gsd(r1 | r2))
try_it("\"R1 AND R2\" (upper case)", stopping_rule_gsd("R1 AND R2"))
try_it("\"r1 and not r2\"", stopping_rule_gsd("r1 and not r2"))
try_it("\"r1 or r2 and r3\"", stopping_rule_gsd("r1 or r2 and r3"))
try_it("r0", stopping_rule_gsd(r0))
try_it("r01", stopping_rule_gsd(r01))
try_it("TRUE", stopping_rule_gsd(TRUE))
try_it("r1 || TRUE (always stops)", stopping_rule_gsd(r1 || TRUE))
try_it("!r1 (stops when H1 is NOT rejected)", stopping_rule_gsd(!r1))
try_it("r1 + r2 (not a logical value)", stopping_rule_gsd(r1 + r2))
try_it("r1 / r2 > 0 (NA when nothing rejected)", stopping_rule_gsd(r1 / r2 > 0))
try_it("isTRUE(r1)", stopping_rule_gsd(isTRUE(r1)))
try_it("t1 (decision time)", stopping_rule_gsd(t1))
try_it("NULL", stopping_rule_gsd(NULL))
try_it("NA_character_", stopping_rule_gsd(NA_character_))
try_it("list()", stopping_rule_gsd(list()))
cond <- "r1 and r2"
try_it("cond (a variable, no !!)", stopping_rule_gsd(cond))
try_it("!!cond", stopping_rule_gsd(!!cond))
k <- 2
try_it("r1 + r2 + r3 >= !!k", stopping_rule_gsd(r1 + r2 + r3 >= !!k))

cat("\n== Using a rule (m = 3, K = 3)\n")
set.seed(1)
raw <- simulate_pvalues_gsd(power_nominal = c(0.9, 0.8, 0.7), corr_matrix = diag(3), info_frac = c(1/3, 2/3, 1), nsim = 4000)
pv <- transform_pvalues_gsd(raw, spending = gsDesign::sfLDOF, grid_size = 128L)
w <- rep(1/3, 3); G <- matrix(0.5, 3, 3); diag(G) <- 0
use <- function(label, rule) try_it(label, calc_power_pvals_gsd(pv, w, G, stopping_rule = rule))
use("r4 (beyond m)", stopping_rule_gsd(r4))
use("list(r1) (one condition, K - 1 = 2)", stopping_rule_gsd(list(r1)))
use("c(\"r1\") (one string)", stopping_rule_gsd(c("r1")))
use("list(\"r1\") (one string in a list)", stopping_rule_gsd(list("r1")))
use("list(r1, r2, r3) (K conditions)", stopping_rule_gsd(list(r1, r2, r3)))
use("list(r1, r2, r3, r1) (K + 1)", stopping_rule_gsd(list(r1, r2, r3, r1)))
use("r1 + r2 (numeric)", stopping_rule_gsd(r1 + r2))
use("r1 / r2 > 0 (NA)", stopping_rule_gsd(r1 / r2 > 0))
use("!r1 (true on the empty set)", stopping_rule_gsd(!r1))
use("r1 || TRUE", stopping_rule_gsd(r1 || TRUE))
use("a plain list, not a rule", list(quote(r1)))
use("a string, not a rule", "r1")

cat("\n== Using a rule with graph_optimise() (fixed sample)\n")
rawf <- simulate_pvalues(power_nominal = c(0.9, 0.8), corr_matrix = diag(2), nsim = 500)
try_it("graph_optimise(..., stopping_rule = )", graph_optimise(rawf, graph_constraint_free(2), trial_success(r1 + r2, verbose = "silent"), stopping_rule = stopping_rule_gsd(r1), verbose = "silent"))
