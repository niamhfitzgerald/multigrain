# Severity 2: misleading in plausible use, or a result that breaks its own contract

The package does something other than what a careful user would take from the help, in a use that is easy to arrive at.

15 entries. Back to the [index](README.md).

Contents: [B1](#B1), [B2](#B2), [B3_power](#B3_power), [B3_simulators](#B3_simulators), [B4](#B4), [B5](#B5), [B6](#B6), [B7](#B7), [B8](#B8), [B9](#B9), [ENV02](#ENV02), [ENV03_power](#ENV03_power), [ENV03_spending](#ENV03_spending), [ENV04](#ENV04), [MEM1](#MEM1)

---

<a name="B1"></a>
## B1. start_graph is ignored when global_search = FALSE

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patches 47, 70, 73)

**What the error is.** A user who switches the global search off and supplies `start_graph` expects the local search to start from that graph. It starts from the default graph every time. In the script the suggested graph scores 1.62 and the default one 1.5505, yet the search starts at 0.333 0.333 0.5 0.5 0.5 and the result is identical to the run without `start_graph`. A sensitivity analysis over starting graphs then reports an agreement that means nothing.

**What causes it.** `graph_optimise()` hands the local stage row 1 of `.build_start_matrix()` (`R/optimisation.R:187-191`; the same at `R/optimisation_gsd.R:198-202`). That function always puts the default seed in row 1 and a fixed-sequence seed in row 2 (`R/optimisation_start.R:8-26`); the user's graphs come after them. The matrix is built for the genetic algorithm, which takes every row as a suggestion.

**Code showing the problem** ([`reprex/B1.R`](reprex/B1.R)):

```r
# B1: start_graph is ignored when global_search = FALSE
# Run: Rscript B1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.6, 0.3), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

w0 <- c(0.6, 0.35, 0.05)                                    # the suggested start graph
G0 <- rbind(c(0, 0.8, 0.2), c(0.7, 0, 0.3), c(0.9, 0.1, 0))
Gd <- matrix(0.5, 3, 3)                                     # the default start graph
diag(Gd) <- 0
cat("gain of the suggested start graph:", calc_power_pvals(P, w0, G0, custom_power = list(g = gain))$g, "\n")
cat("gain of the default start graph  :", calc_power_pvals(P, rep(1, 3) / 3, Gd, custom_power = list(g = gain))$g, "\n")

a <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent",
                    start_graph = list(list(hyp_weight = w0, trans_matrix = G0)))
b <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent")

# local_output$x0 holds w1, w2, G[1,2], G[2,1], G[3,1] of the point the search started from
cat("search started at, with start_graph   :", round(a$local_output$x0, 3), "\n")
cat("search started at, without start_graph:", round(b$local_output$x0, 3), "\n")
cat("result with start_graph   : weights", round(unname(a$hyp_weight), 3), "gain", a$power$trial_success, "\n")
cat("result without start_graph: weights", round(unname(b$hyp_weight), 3), "gain", b$power$trial_success, "\n")
cat("EXPECTED: with start_graph the search starts at 0.6 0.35 0.8 0.7 0.9, the suggested graph\n")
```

Output on `gsd-build`:

```
gain of the suggested start graph: 1.62
gain of the default start graph  : 1.5505
search started at, with start_graph   : 0.333 0.333 0.5 0.5 0.5
search started at, without start_graph: 0.333 0.333 0.5 0.5 0.5
result with start_graph   : weights 0.66 0.327 0.013 gain 1.628
result without start_graph: weights 0.66 0.327 0.013 gain 1.628
EXPECTED: with start_graph the search starts at 0.6 0.35 0.8 0.7 0.9, the suggested graph
```

**Potential fix.** Give the local stage the user's rows followed by the default start graph, and start from the row with the highest gain on the p-values of that stage. `.build_start_matrix()` gets an argument `user_only` that drops its two built-in seeds.

```r
# graph_optimise() and graph_optimise_gsd()
} else if (!.is_default_start_graph(start_graph)) {
    x0_for_local <- rbind(
        .build_start_matrix(graph_constraint, start_graph, user_only = TRUE),
        create_start_params(graph_constraint)
    )
}

# .graph_optimise_local() and its group sequential twin, before nloptr()
if (is.matrix(x0)) {
    best <- 1L
    if (nrow(x0) > 1L) {
        best <- c(which.max(apply(x0, 1L, obj_fun)), 1L)[[1L]]
    }
    x0 <- x0[best, , drop = TRUE]
}
```

With this change the script's search starts at 0.6 0.35 0.8 0.7 0.9 and returns a different graph (gain 1.6285 against 1.628). A suggestion that scores below the default graph is not used and a message says so; starting where the user says regardless is the alternative, and in the first version of the fix it ended below the run with no suggestion. Patch 70 changes the weights filled in for a start graph that gives only the matrix, from `rep(1, m)` to `rep(1 / m, m)` (`R/optimisation_start.R:37`).

---

<a name="B2"></a>
## B2. A fixed constraint value below 0.001 is not kept

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 49)

**What the error is.** A user fixes an epsilon edge at 1e-4 in the constraint. Whenever the solution of the global search is the one returned, the edge comes back as 0.001: ten times the fixed value, in a graph that reports `graph_valid = TRUE` and still carries the constraint that it breaks. During the search itself a fixed weight below 1e-4 or a fixed edge below 1e-5 is evaluated as 0, so the gain being maximised belongs to a different graph from the one the constraint describes. Epsilon edges are the usual reason for typing a value this small.

**What causes it.** The clean-up thresholds meant for the entries the optimiser sets are applied to every entry. `param_to_solution(process = TRUE)` zeroes values below 1e-4 (weights) or 1e-5 (edges) and raises those up to 1e-3 to 0.001 (`R/post_optim_processing.R:18-19, 27-28`), and the objective closures zero the same entries before the kernel runs (`R/objective_function.R:66-67`, `R/objective_function_gsd.R:75-76`). The local solution is put right afterwards by `repair_graph()`, which pins fixed entries (`R/post_optim_processing.R:82-90`); the global solution is not passed through it (`R/optimisation.R:342`).

**Code showing the problem** ([`reprex/B2.R`](reprex/B2.R)):

```r
# B2: a fixed constraint value below 0.001 is not kept
# Run: Rscript B2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7, 0.6), nsim = 4000)
gain <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")

tc <- matrix(NA_real_, 4, 4)
diag(tc) <- 0
tc[1, 4] <- 1e-4                      # an epsilon edge H1 -> H4, fixed by the user
con <- graph_constraint(trans_constraint = tc)

# a short global search, and a local search on 300 rows so that the global solution is returned
ctrl <- control_global(multigrain_control(), popSize = 40, maxiter = 30, run = 10)
ctrl <- control_nsim_local(ctrl, 300)

set.seed(3)
res <- graph_optimise(P, con, gain, control = ctrl, verbose = "silent")
cat("solution taken from the", res$solution$opt_source, "search\n")
cat("constraint on G[1, 4]:", con$trans_constraint[1, 4], "\n")
cat("returned G[1, 4]     :", res$trans_matrix[1, 4], "\n")
cat("EXPECTED: returned G[1, 4] equal to the fixed value 1e-04\n")
```

Output on `gsd-build`:

```
solution taken from the global search
constraint on G[1, 4]: 1e-04
returned G[1, 4]     : 0.001
EXPECTED: returned G[1, 4] equal to the fixed value 1e-04
```

**Potential fix.** Apply the thresholds only where the constraint is `NA`. In `param_to_solution()`:

```diff
+        free_w <- is.na(hyp_constraint)
+        free_g <- is.na(trans_constraint)
-        w_sol[w_sol < 1e-4] <- 0
-        w_sol[w_sol > 1e-4 & w_sol < 1e-3] <- 0.001
+        w_sol[free_w & w_sol < 1e-4] <- 0
+        w_sol[free_w & w_sol > 1e-4 & w_sol < 1e-3] <- 0.001
 ...
-        G_sol[G_sol < 1e-5] <- 0
-        G_sol[G_sol > 1e-5 & G_sol < 1e-3] <- 0.001
+        G_sol[free_g & G_sol < 1e-5] <- 0
+        G_sol[free_g & G_sol > 1e-5 & G_sol < 1e-3] <- 0.001
```

The two objective closures get the same mask on their two lines. With this change the script returns 1e-04. Nothing changes for free entries, or for constraints whose fixed values are 0 or at least 0.001.

---

<a name="B3_power"></a>
## B3_power. calc_power_pvals() accepts missing and out-of-range p-values and any alpha

- Functions: calc_power_pvals(), graph_optimise()
- Branches: main and gsd-build
- Potential fix: tested (patches 4, 59)

**What the error is.** `calc_power_pvals()` passes its p-value matrix and its level to the kernel unchecked. A missing p-value counts as "not rejected" with no message: with 600 of 2,000 p-values of H2 set to `NA`, the local power of H2 falls from 0.754 to 0.530 and the other two move as well. A p-value of -1 is rejected for a hypothesis whose weight is 0, and `alpha = 40` is accepted and gives local power 1, 1, 1. `graph_optimise()` refuses that alpha but optimises on the same p-values. In practice the bad values come from upstream: `simulate_pvalues(c(0.9, 80, 0.7))` returns a column of `NaN`, which is then reported as a power of 0 for H2.

**What causes it.** The only checks are `check_double_matrix(pvals)` and `rlang::check_number_decimal(alpha, min = 0)` (`R/calc_power.R:124-128`). The kernel tests `cur_p[i] < cur_a[i]` (`src/graph_shortcut.cpp:110`), which is false for `NA` and `NaN` and true for a negative p-value at any level, a level of 0 included. `graph_optimise()` checks `pvals` for its type only (`R/optimisation.R:111`). The group sequential functions validate both (`R/check_gsd.R:124-145, 154-186`).

**Code showing the problem** ([`reprex/B3_power.R`](reprex/B3_power.R)):

```r
# B3_power: calc_power_pvals() accepts missing p-values and any alpha
# Run: Rscript B3_power.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2
cat("local power, complete p-values:      ", calc_power_pvals(pvals, w, G)$local_power, "\n")

with_na <- pvals
with_na[1:600, 2] <- NA                      # H2 not available in 30% of the trials
cat("local power, 600 p-values of H2 NA:  ", calc_power_pvals(with_na, w, G)$local_power, "\n")

negative <- rbind(c(-1, 0.9, 0.02))          # H1 has weight 0 below
hit <- calc_power_pvals(negative, c(0, 0.5, 0.5), G)$local_power
cat("rejected for p = (-1, 0.9, 0.02), w = (0, 0.5, 0.5):", hit == 1, "\n")

cat("local power at alpha = 40:           ", calc_power_pvals(pvals, w, G, alpha = 40)$local_power, "\n")
cat("EXPECTED: an error for each of the last three calls, as calc_power_pvals_gsd() gives\n")
```

Output on `gsd-build`:

```
local power, complete p-values:       0.857 0.754 0.648
local power, 600 p-values of H2 NA:   0.848 0.53 0.6245
rejected for p = (-1, 0.9, 0.02), w = (0, 0.5, 0.5): TRUE FALSE FALSE
local power at alpha = 40:            1 1 1
EXPECTED: an error for each of the last three calls, as calc_power_pvals_gsd() gives
```

**Potential fix.** One helper for both functions, called in place of the old checks:

```r
.check_pvals_alpha <- function(pvals, alpha, call = rlang::caller_env()) {
    check_double_matrix(pvals, call = call)
    rlang::check_number_decimal(alpha, min = 0, max = 1, call = call)
    if (alpha <= 0 || alpha >= 1) {
        cli::cli_abort(
            "{.arg alpha} must be greater than 0 and less than 1, not {alpha}.",
            call = call
        )
    }
    if (length(pvals) == 0L) return(invisible(NULL))
    lowest <- min(pvals)      # min() and max() propagate NA and NaN
    highest <- max(pvals)
    if (is.na(lowest) || is.na(highest)) {
        cli::cli_abort("{.arg pvals} contains {.val {NA}} or {.val {NaN}}.", call = call)
    }
    if (lowest < 0 || highest > 1) {
        cli::cli_abort("{.arg pvals} contains values outside [0, 1].", call = call)
    }
    invisible(NULL)
}
```

With this change the script stops at the call with missing values: "`pvals` contains NA or NaN". Valid input gives the same numbers. An `alpha` of exactly 0 or 1 becomes an error as well, which is a judgement call: both were accepted before and gave power 0 and 1.

---

<a name="B3_simulators"></a>
## B3_simulators. The simulators do not validate power_nominal, and simulate_pvalues() does not validate nsim

- Functions: simulate_pvalues(), simulate_pvalues_gsd()
- Branches: main and gsd-build (simulate_pvalues_gsd() on gsd-build only)
- Potential fix: tested (patch 26)

**What the error is.** This entry is the simulators' share of B3 (the fixed-sample functions do not validate their input) together with DOC17e. `simulate_pvalues(c(0.9, 80, 0.7))`, with 80 typed for 0.80, returns a matrix whose second column is `NaN` in all 2000 rows; the only sign is a base R warning, "NaNs produced". `simulate_pvalues_gsd()` does the same. A nominal power of exactly 0 or 1 gives p-values that are all 1 or all 0. DOC17e: `simulate_pvalues(nsim = 0)` stops inside mvtnorm with "non-conformable arguments", and `nsim = -5` with "invalid arguments".

**What causes it.** `power_nominal` is checked for its type only (`R/sim_pvals.R:66`, `R/sim_pvals_gsd.R:92`). `calc_ncp()` then computes `qnorm(1 - alpha) - qnorm(1 - power)` (`R/utils.R:59`), which is `NaN` for a power outside [0, 1] and infinite at 0 and 1. `simulate_pvalues()` checks `nsim` with `rlang::check_number_whole(nsim)` and no minimum (`R/sim_pvals.R:70`); `simulate_pvalues_gsd()` already has `min = 1`.

**Code showing the problem** ([`reprex/B3_simulators.R`](reprex/B3_simulators.R)):

```r
# B3 (simulators) and DOC17e: power_nominal and nsim are not validated by the simulators
# Run: Rscript B3_simulators.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

msg <- tryCatch(simulate_pvalues(c(0.9, 0.8), nsim = 0), error = function(e) conditionMessage(e))
cat("simulate_pvalues(nsim = 0) says:", msg, "\n")

set.seed(1)
P <- simulate_pvalues(c(0.9, 80, 0.7), nsim = 2000)          # 80 typed for 0.80
cat("NaN in each column of the simulated p-values:", colSums(is.nan(P)), "\n")
cat("EXPECTED: an error that names nsim, and an error that names the second",
    "element of power_nominal\n")
```

Output on `gsd-build`:

```
simulate_pvalues(nsim = 0) says: non-conformable arguments
Warning message:
In stats::qnorm(1 - power) : NaNs produced
NaN in each column of the simulated p-values: 0 2000 0
EXPECTED: an error that names nsim, and an error that names the second element of power_nominal
```

**Potential fix.** Both simulators call a shared check of `power_nominal`, and `simulate_pvalues()` gets the minimum for `nsim` that the group sequential simulator has.

```r
.check_power_nominal <- function(power_nominal, call = rlang::caller_env()) {
    bad <- which(
        is.na(power_nominal) | power_nominal <= 0 | power_nominal >= 1
    )
    if (length(bad) > 0L) {
        cli::cli_abort(
            c(
                "{.arg power_nominal} must hold values strictly between 0 \\
                and 1.",
                x = "It holds {power_nominal[bad]} (element {bad})."
            ),
            call = call
        )
    }
    invisible(TRUE)
}

# in simulate_pvalues()
rlang::check_number_whole(nsim, min = 1)
```

With this change the script prints "`nsim` must be a whole number larger than or equal to 1" and then stops with "It holds 80 (element 2)". Valid input gives the same draws. Judgement call: a power of exactly 0 or 1 is now refused; a true null hypothesis is written as `power_nominal = alpha`.

---

<a name="B4"></a>
## B4. The simulators accept matrices that are not correlation matrices

- Functions: simulate_pvalues(), simulate_pvalues_gsd()
- Branches: main and gsd-build (simulate_pvalues_gsd() on gsd-build only)
- Potential fix: tested (patch 25)

**What the error is.** `corr_matrix` is checked for its type only. A matrix filled in from pairwise guesses that is not positive semidefinite (smallest eigenvalue -0.22 in the script) gives one generic mvtnorm warning, "sigma is numerically not positive semidefinite", and p-values that do not follow the model: five true null hypotheses are rejected at rates of 0.026 to 0.030 at a level of 0.025. A covariance matrix passed by mistake (diagonal 4) gives a power of 0.74 for a nominal 0.90 with no message at all. Any study of how the correlation matrix affects a design is exposed to the first case.

**What causes it.** `simulate_pvalues()` calls only `check_double_matrix(corr_matrix)` (`R/sim_pvals.R:69`) and passes the matrix to `mvtnorm::rmvnorm()` as `sigma` (line 77). `simulate_pvalues_gsd()` adds a check of the dimensions and nothing else (`R/sim_pvals_gsd.R:96-105`). `rmvnorm()` only warns about a negative eigenvalue and then draws from another matrix, and a diagonal other than 1 is a valid covariance for it.

**Code showing the problem** ([`reprex/B4.R`](reprex/B4.R)):

```r
# B4: the simulators accept matrices that are not correlation matrices
# Run: Rscript B4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Pairwise guesses for five endpoints; together they are not a correlation matrix.
S <- matrix(0.6, 5, 5)
diag(S) <- 1
S[1, 2] <- S[2, 1] <- -0.4
S[3, 4] <- S[4, 3] <- 0.95
cat("smallest eigenvalue:", round(min(eigen(S)$values), 3), "\n")

set.seed(1)
P <- withCallingHandlers(
    simulate_pvalues(rep(0.025, 5), corr_matrix = S, nsim = 2e5),   # five true nulls
    warning = function(w) {
        cat("only message:", conditionMessage(w), "\n")
        invokeRestart("muffleWarning")
    }
)
cat("P(p < 0.025) for the five true nulls:", round(colMeans(P < 0.025), 4), "\n")

# A covariance matrix passed by mistake
P2 <- simulate_pvalues(c(0.9, 0.9), corr_matrix = 4 * diag(2), nsim = 2e5)
cat("diagonal of 4, no message: power", round(colMeans(P2 < 0.025), 3), "for a nominal 0.9\n")
cat("EXPECTED: an error for both matrices; otherwise 0.025 for each true null",
    "and 0.9 for each power\n")
```

Output on `gsd-build`:

```
smallest eigenvalue: -0.224
only message: sigma is numerically not positive semidefinite
P(p < 0.025) for the five true nulls: 0.0303 0.0298 0.0259 0.0257 0.0265
diagonal of 4, no message: power 0.74 0.739 for a nominal 0.9
EXPECTED: an error for both matrices; otherwise 0.025 for each true null and 0.9 for each power
```

**Potential fix.** One helper in `R/sim_pvals.R`, called by both simulators, requires a finite, symmetric matrix of the right size with a unit diagonal, entries in [-1, 1] and no negative eigenvalue. Its core:

```r
tolerance <- sqrt(.Machine$double.eps)
problem <- if (!all(is.finite(corr_matrix))) {
    "It has missing or infinite entries."
} else if (
    !isSymmetric(corr_matrix, tol = tolerance, check.attributes = FALSE)
) {
    "It is not symmetric."
} else if (any(abs(diag(corr_matrix) - 1) > tolerance)) {
    "Its diagonal is not 1: is it a covariance matrix?"
} else if (any(abs(corr_matrix) > 1 + tolerance)) {
    "It has entries outside [-1, 1]."
} else {
    values <- eigen(corr_matrix, symmetric = TRUE, only.values = TRUE)$values
    if (any(values < -tolerance * abs(values[[1L]]))) {
        "It is not positive semidefinite (smallest eigenvalue \\
        {signif(min(values), 3)})."
    }
}
# then: cli::cli_abort(c("{.arg corr_matrix} must be a correlation matrix.", x = problem))
```

With this change the script stops at the first matrix with "`corr_matrix` must be a correlation matrix" and the eigenvalue; the second is refused for its diagonal. A singular matrix (two perfectly correlated endpoints) is still accepted. The two tolerances are the ones `rmvnorm()` applies itself.

---

<a name="B5"></a>
## B5. A string objective of trial_success() is written into C++ unchecked

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the trial_success_gsd() part on gsd-build only)
- Potential fix: tested (patches 32, 33, 34, 68, 70)

**What the error is.** A gain given as a string is parsed by R and pasted into the C++ loop with no check. `"abs(r1 - 0.5) + r2"` compiles and returns 0.5 on the four rejection patterns, where R gives 1 (the compiler takes C's integer `abs()`), and a `system()` call in a string ran once per simulated trial. The same text typed as an expression is refused. Two neighbours: `TRUE` and `FALSE` are compiled as C++ integers, so `(TRUE + TRUE) / (TRUE + TRUE + TRUE)` is 0, and `trial_success_gsd()` compiles an `NA` constant as 0 without a message.

**What causes it.** `resolve_expr()` validates a captured expression and passes a string through untouched (`R/trial_success.R:204-208`). `replace_r_indices()` parses the string (`:381`), and `parse_and_transform()` copies every call and symbol it does not know into the C++ text (`:515-518`, `:537-540`) and a logical literal as it stands (`:548-551`). The help says so (`:75-82`). `trial_success_gsd()` writes a logical constant as `if (isTRUE(node)) "1.0" else "0.0"` (`R/trial_success_gsd.R:827-832`), so `NA` becomes `0.0`.

**Code showing the problem** ([`reprex/B5.R`](reprex/B5.R)):

```r
# B5: a string objective of trial_success() is pasted into C++ unchecked
# Run: Rscript B5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- rbind(c(TRUE, TRUE), c(TRUE, FALSE), c(FALSE, TRUE), c(FALSE, FALSE))

g <- trial_success("abs(r1 - 0.5) + r2", verbose = "silent")
cat("abs(r1 - 0.5) + r2 on the four rejection patterns\n")
cat("  compiled gain:", g$func(x), "\n")
cat("  plain R      :", mean(abs(x[, 1] - 0.5) + x[, 2]), "\n")

# Any C function can be called from a string, including system().
# The shell command appends a line to a file in the working directory.
setwd(tempdir())
g2 <- trial_success("r1 + r2 + 0 * system(\"echo ran >> B5_marker.txt\")",
                    verbose = "silent")
invisible(g2$func(x))
cat("system() in a string objective ran", length(readLines("B5_marker.txt")),
    "times for", nrow(x), "simulated trials\n")
cat("EXPECTED: both strings refused, as the same text typed as an expression is\n")
```

Output on `gsd-build`:

```
abs(r1 - 0.5) + r2 on the four rejection patterns
  compiled gain: 0.5
  plain R      : 1
system() in a string objective ran 4 times for 4 simulated trials
EXPECTED: both strings refused, as the same text typed as an expression is
```

**Potential fix.** Hold the parsed string to the grammar of expressions just before it is translated, and count the operands of each operator. In `R/trial_success.R`:

```r
# replace_r_indices(): the tree holds the placeholders for && and ||
ast <- str2lang(fixed_expr)
validate_expr_symbols(ast, logic_ops = c("%AND%", "%OR%"))

validate_expr_symbols <- function(expr, logic_ops = c("&&", "||")) {
    if (is.call(expr)) {
        fn <- expr[[1]]
        allowed <- c("+", "-", "*", "/", "(", "!", logic_ops,
                     gsd_gain_compare_ops)
        # ... abort unless `fn` is a symbol in `allowed` ...
        .trial_success_check_arity(expr)    # refuses `+`(r1, r2, r3)
        lapply(expr[-1], validate_expr_symbols, logic_ops = logic_ops)
    } else if (is.numeric(expr) || is.logical(expr)) {
        if (!is.finite(expr)) {
            cli::cli_abort("Constants in the trial success expression \\
                must be finite, not {.val {expr}}.")
        }
    }
}
```

With this change the script stops at its first call ("Unsupported operator or function `abs`"); logical literals become `1.0` and `0.0`, and both constructors refuse a constant that is not finite. A judgement call: the help offered strings as a way round the operator check, so `sqrt()` or `pow()` in a string, which used to compile, are now errors. In exchange comparisons and `!` join the grammar (`(r1 + r2 + r3 >= 2)` is "at least two of three"), with their own parentheses next to `&&` or `||`.

---

<a name="B6"></a>
## B6. The returned graph can be worse than the graph the search started from

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patches 48, 69)

**What the error is.** With `control_nsim_local()` below the number of simulated trials, the graph reported as optimal can score lower on the full p-value matrix than the default start graph. In the script the local search runs on 1,000 of 20,000 rows: the start graph has gain 1.6652 on all rows and the returned graph 1.65275. The result is printed as "Optimal graph found" with no warning. A user who subsamples to save time can end with a design that is worse than the default graph.

**What causes it.** The local search maximises the gain on its subsample (`R/optimisation.R:434`), and a graph tuned to 1,000 rows can lose on the other 19,000. `choose_graph()` then compares the global and the local result with each other only (`R/choose_graph.R:17-54`), and with `global_search = FALSE` it returns the local result unconditionally (lines 18-24). The graph the search started from is never scored on the full matrix.

**Code showing the problem** ([`reprex/B6.R`](reprex/B6.R)):

```r
# B6: the returned graph can be worse than the graph the search started from
# Run: Rscript B6.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.56, 0.77, 0.61), nsim = 20000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

Gd <- matrix(0.5, 3, 3)               # the default start graph: equal weights, equal edges
diag(Gd) <- 0
start_gain <- calc_power_pvals(P, rep(1, 3) / 3, Gd, custom_power = list(g = gain))$g

ctrl <- control_nsim_local(multigrain_control(), 1000)   # local search on 1,000 of the 20,000 rows
set.seed(2)
res <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE,
                      control = ctrl, verbose = "silent")

cat("gain of the default start graph on all rows:", start_gain, "\n")
cat("gain of the returned graph on all rows     :", res$power$trial_success, "\n")
cat("returned weights:", round(unname(res$hyp_weight), 3), " source:", res$solution$opt_source, "\n")
cat("EXPECTED: a returned gain of at least", start_gain, "\n")
```

Output on `gsd-build`:

```
gain of the default start graph on all rows: 1.6652
gain of the returned graph on all rows     : 1.65275
returned weights: 0.515 0.279 0.206  source: local
EXPECTED: a returned gain of at least 1.6652
```

**Potential fix.** Score the start graphs (the default one and any in `start_graph`) on all rows and put the best of them into the final comparison. In `graph_optimise()` and `graph_optimise_gsd()`, after `choose_graph()`:

```r
best_graph_result <- keep_start_graph(
    best_graph_result, ga_result, local_result,
    start_result = best_start_graph(graph_constraint, start_graph,
        gain = function(hyp_weight, trans_matrix) {    # all rows; graph_shortcut_gsd(...)$time in the GSD twin
            trial_success$func(graph_shortcut(pvals = pvals, alpha = alpha, w = hyp_weight, G = trans_matrix))
        })
)

# keep_start_graph(): the start graph replaces a result that is invalid or strictly worse
use_start <- !chosen_valid ||
    isTRUE(start_result$start_trial_success > chosen_trial_success)
if (!use_start) {
    return(best_graph_result)
}
list(
    hyp_weight = start_result$start_hyp_weight,
    trans_matrix = start_result$start_trans_matrix,
    source = "start"
)
```

With this change the script returns equal weights with `opt_source` equal to `"start"` and gain 1.667; the gain is above 1.6652 since the start graph still goes through the final pruning step. `opt_source` gains a third value, which downstream code may need to know about, and `print()` then leads with "Start graph returned after pruning" in place of "Optimal graph found" (patch 69). The alternative is a warning that leaves the worse graph in place.

---

<a name="B7"></a>
## B7. A num_threads of 65,537 or more ends the R session

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (the group sequential kernel on gsd-build only)
- Potential fix: tested (patch 6)

**What the error is.** Round 1 finding B7 and round 2 finding MEM2 are one defect; MEM2 located the threshold. `graph_optimise(num_threads = 65537)` ends the R session with a segmentation fault at its first parallel evaluation, while 65,536 runs normally; the group sequential kernel crashes at 65,537 too. Nothing is gained from such a request: on the 2-core test machine a call with 2, 64 or 65,536 threads ran with the same 2 or 3 operating system threads. A value of 2^31 or more is refused with "num_threads must be >= 1", which points the wrong way. Someone who types a large number to mean "all cores" loses the session and everything in it.

**What causes it.** `graph_optimise()` requires a whole number of at least 1 (`R/optimisation.R:132`), and the kernels refuse only `num_threads < 1` (`src/graph_shortcut.cpp:311-312`, `src/graph_shortcut_gsd.cpp:359-360`) before passing the value to `RcppParallel::parallelFor()` (`src/graph_shortcut.cpp:362-363`, `src/graph_shortcut_gsd.cpp:408-409`). A debugger backtrace of the crash ends in TBB's `arena::free_arena()`, reached from the destructor of the `task_arena` that `parallelFor()` creates with the requested size. A value of 2^31 or more becomes `NA_integer_` when converted to `int`; that is the smallest `int`, so the `< 1` test answers.

**Code showing the problem** ([`reprex/B7.R`](reprex/B7.R)):

```r
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
```

Output on `gsd-build`:

```
cores on this machine: 2
num_threads = 65536: child exit status 0
num_threads = 65537: child exit status 139 (139 = segmentation fault)
EXPECTED: exit status 0 for both, with the request capped at the number of cores, or an R error
```

**Potential fix.** Cap the request at the hardware concurrency in both parallel kernels, and give `NA` its own message (needs `#include <thread>`):

```cpp
if (num_threads == NA_INTEGER)
  stop("num_threads must not be NA (a value of 2^31 or more becomes NA "
       "when converted to an integer).");
if (num_threads < 1)
  stop("num_threads must be >= 1.");

unsigned max_threads = std::thread::hardware_concurrency();
if (max_threads == 0)   // "unknown": a ceiling far below the arena limit
  max_threads = 256;
if (static_cast<unsigned>(num_threads) > max_threads)
  num_threads = static_cast<int>(max_threads);
```

With this change both child processes of the script exit with status 0. A request above the number of cores now runs with as many threads as there are cores, which also changes the automatic grain size; the rejections depend on neither. The alternative is an R error for such a request. Tested on Linux only.

---

<a name="B8"></a>
## B8. The help page of trial_success() is malformed and its examples do not parse, so R CMD check fails

- Functions: trial_success() (help page; one argument description is inherited by trial_success_gsd())
- Branches: gsd-build only
- Potential fix: tested (patches 31, 61)

**What the error is.** `man/trial_success.Rd` has two faults (round 1 B8; round 2 DOC5 is the detail). `tools::checkRd()` reports two structural problems, and the examples extracted from the page do not parse. `R CMD check` puts the examples of all help pages into one file, so it reports an ERROR and runs no example of the package (check log of the stress test: "will not attempt to run examples"). The repository's check workflow runs on pushes and pull requests to `main` only (`.github/workflows/R-CMD-check.yaml:9-13`), so nothing flagged the fault on `gsd-build` and it surfaces at the merge.

**What causes it.** The example at `R/trial_success.R:148` is `sprintf(“%s * r1 + r2”, w)` with typographic quotes, which R cannot parse. They were typed in `d9a3f8e` and reached `man/trial_success.Rd:159` in `77ba79a`; the same quotes are in the prose at lines 12 and 22 to 28. Separately, the `\references{` block opened at `man/trial_success.Rd:165` is never closed: this came from the merge commit `b5d0067`, in which the generated file was merged by hand. `main` has neither fault.

**Code showing the problem** ([`reprex/B8.R`](reprex/B8.R)):

```r
# B8: the help page of trial_success() is malformed and its examples do not parse
# Run from the repository root: Rscript B8.R   (reads man/ and R/; needs only base R)
# fmt: skip file
rd <- "man/trial_success.Rd"

# 1. Structure of the help file
problems <- capture.output(print(suppressWarnings(tools::checkRd(rd))))
problems <- grep("unexpected", problems, value = TRUE)
cat("structural problems reported by tools::checkRd():", length(problems), "\n")
cat(sprintf("  %s\n", problems), sep = "")

# 2. The examples, as R CMD check extracts them
ex <- tempfile(fileext = ".R")
suppressWarnings(tools::Rd2ex(rd, ex))
parsed <- tryCatch({ parse(ex); "yes" }, error = function(e) "no")
cat("examples parse:", parsed, "\n")

# 3. Typographic quotes (UTF-8 bytes e2 80 9c and e2 80 9d) in the roxygen
#    source the page is generated from
src <- readLines("R/trial_success.R", warn = FALSE)
curly <- grepl("\xe2\x80[\x9c\x9d]", src, useBytes = TRUE)
cat("lines of R/trial_success.R with typographic quotes:", which(curly), "\n")
cat("EXPECTED: no structural problem, examples that parse, and no such lines\n")
```

Output on `gsd-build`:

```
structural problems reported by tools::checkRd(): 2
  prepare_Rd: man/trial_success.Rd:171: unexpected section header '\seealso'
  prepare_Rd: man/trial_success.Rd:175: unexpected END_OF_INPUT '
examples parse: no
lines of R/trial_success.R with typographic quotes: 12 22 23 25 27 28 148
EXPECTED: no structural problem, examples that parse, and no such lines
```

**Potential fix.** Correct the roxygen source and regenerate the page from it. In `R/trial_success.R`:

```diff
-#' expr_str <- sprintf(“%s * r1 + r2”, w)
+#' expr_str <- sprintf("%s * r1 + r2", w)
```

Replace `“` and `”` by `"` on lines 12 and 22 to 28 as well, then run `roxygen2::roxygenise()` (the tested patches used roxygen2 8.1.0.9000; `DESCRIPTION` names 8.1.0), which also closes the `\references` block, since that fault exists only in the generated file. Run in the fixed tree, the script reports no structural problem, examples that parse, and no line with typographic quotes; no code changes. The sentence lost from "Interpreting the gain" on the same page is a separate fault with the same cure: see DOC4. Two ways to stop a repeat, neither tested: settle a conflict in `man/` by running `roxygen2::roxygenise()` and never by editing the generated file, and add `gsd-build` to the `pull_request` branches of the check workflow.

---

<a name="B9"></a>
## B9. A gain, and any saved optimisation result, cannot be used after it is reloaded

- Functions: trial_success(), trial_success_gsd(), calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: tested (patches 36, 60, 68)

**What the error is.** After `saveRDS()` and `readRDS()` a gain still prints its objective, and every use of it stops with "NULL value passed as symbol address" (round 1 B9). An optimisation result carries its gain, so a saved result cannot be scored on fresh p-values; the result shipped as `graph_optimal_example` is in that state. Round 2 (ENV06) found the same after `load()`, in a socket worker, and for a gain returned from a forked child. The message does not say that the gain must be built again.

**What causes it.** `$func` is the R wrapper that `Rcpp::sourceCpp()` creates (`R/trial_success.R:314, 324`; `R/trial_success_gsd.R:713, 723`). It holds a pointer into a shared library of the building process, and R serialises such a pointer as `NULL`. The object also keeps the C++ source it was built from (`cpp_code`, `:327`), but nothing uses it: the consumers call `$func` directly (`R/calc_power.R:248`, `R/optimisation.R:320`).

**Code showing the problem** ([`reprex/B9.R`](reprex/B9.R)):

```r
# B9: a saved gain, and so a saved optimisation result, cannot be used after reloading
# Run: Rscript B9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

g <- trial_success(r1 + 0.5 * r2, verbose = "silent")
file <- tempfile(fileext = ".rds")
saveRDS(g, file)
g_reloaded <- readRDS(file)      # as in a later session, or on another machine

set.seed(1)
p <- simulate_pvalues(c(0.9, 0.8), nsim = 10000)
w <- c(0.5, 0.5)
G <- rbind(c(0, 1), c(1, 0))
cat("gain before saving  :", calc_power_pvals(p, w, G, custom_power = g)$custom_power, "\n")
after <- tryCatch(
    format(calc_power_pvals(p, w, G, custom_power = g_reloaded)$custom_power),
    error = function(e) paste("ERROR:", conditionMessage(e))
)
cat("gain after reloading:", after, "\n")
cat("C++ source still held by the reloaded object:", nchar(g_reloaded$cpp_code), "characters\n")
cat("EXPECTED: the same value after reloading, or a message saying how to rebuild the gain\n")
```

Output on `gsd-build`:

```
gain before saving  : 1.2748
gain after reloading: ERROR: NULL value passed as symbol address
C++ source still held by the reloaded object: 357 characters
EXPECTED: the same value after reloading, or a message saying how to rebuild the gain
```

**Potential fix.** Test once whether the function is alive and, if not, recompile it from the stored source. One helper for both families, called by the two power functions and the two optimisers before the gain is used:

```r
.revive_trial_success <- function(x, verbose = multigrain_verbosity()) {
    probe <- matrix(if (is_trial_success_gsd(x)) 0L else FALSE, 1L, x$m)
    alive <- tryCatch({ x$func(probe); TRUE }, error = function(cnd) FALSE)
    if (alive) {
        return(x)
    }
    if (!rlang::is_string(x$cpp_code) || !nzchar(x$cpp_code)) {
        cli::cli_abort("... create it again with trial_success() ...")
    }
    local_env <- new.env()
    sourceCpp(code = x$cpp_code, env = local_env, cacheDir = .trial_success_cache_dir())   # entry ENV02
    x$func <- local_env$powerFunc
    x
}

# graph_optimise(), after the argument checks
trial_success <- .revive_trial_success(trial_success, verbose = verbose)
```

With this change the script prints "Trial success function recompiled from its stored C++ source" and the value from before saving (1.2748); a live gain is returned untouched, at the cost of one call on a one-row matrix. Calling `$func` directly on a reloaded object still fails. A judgement call: C++ text stored in a file is compiled, so an `.rds` from an untrusted source has its code built; the alternative is an error that says to call the constructor again.

---

<a name="ENV02"></a>
## ENV02. Gains built at the same moment in forked workers fail at random

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: tested (patch 35)

**What the error is.** A sweep that builds one gain per scenario inside `parallel::mclapply()` loses some of its workers: with 8 workers, 2 to 6 failed in every run here, with errors such as "Error in load(file = token_file) : empty (zero-byte) input file". `mclapply()` turns each failure into an error object in the result list and gives only a warning, so the sweep comes back with holes. No worker returned a wrong value. Which workers fail varies from run to run, and with 4 workers one run in 14 lost none.

**What causes it.** `sourceCpp(code = cpp_code, env = local_env)` (`R/trial_success.R:314`, `R/trial_success_gsd.R:713`) leaves Rcpp's build cache at its default, `getOption("rcpp.cache.dir", tempdir())`. Forked children share the `tempdir()` of their parent. Rcpp keeps its index files there, among them `token.rds`, a counter of its libraries that every build loads and saves again without a lock (`Rcpp:::.sourceCppDynlibUniqueToken()`), so one worker reads a file while another is writing it.

**Code showing the problem** ([`reprex/ENV02.R`](reprex/ENV02.R)):

```r
# ENV02: gains built at the same moment in forked workers fail at random
# Run: Rscript ENV02.R   (needs the gsd-build build of multigrain; Unix only, since it forks)
# fmt: skip file
library(multigrain)

x <- rbind(c(TRUE, FALSE), c(TRUE, TRUE))   # the mean of k * r1 + r2 on x is k + 0.5

# A sweep over a weight k: one gain per scenario, each built in its own worker
out <- suppressWarnings(parallel::mclapply(1:8, function(k) {
    g <- trial_success(!!k * r1 + r2, verbose = "silent")
    g$func(x)
}, mc.cores = 8, mc.preschedule = FALSE))

failed <- vapply(out, inherits, logical(1), what = "try-error")
cat("workers that failed:", sum(failed), "of 8\n")
cat(sprintf("  %s\n", unique(trimws(unlist(out[failed])))), sep = "")
cat("values from the others:", unlist(out[!failed]), "\n")
cat("(a race between the workers: the count varies from run to run)\n")
cat("EXPECTED: 0 of 8 failed and the values 1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5\n")
```

Output on `gsd-build`:

```
workers that failed: 6 of 8
  Error in load(file = token_file) : empty (zero-byte) input file
values from the others: 4.5 6.5
(a race between the workers: the count varies from run to run)
EXPECTED: 0 of 8 failed and the values 1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5
```

**Potential fix.** Give each R process its own cache directory, and respect one the user has set. In `R/trial_success.R`:

```r
.trial_success_cache_dir <- function() {
    cache_dir <- getOption("rcpp.cache.dir")
    if (is.null(cache_dir)) {
        cache_dir <- file.path(tempdir(), paste0("multigrain-", Sys.getpid()))
        dir.create(cache_dir, showWarnings = FALSE)
    }
    cache_dir
}

# both constructors
sourceCpp(
    code = cpp_code,
    env = local_env,
    cacheDir = .trial_success_cache_dir()
)
```

With this change the script reports 0 of 8 failed and all eight values, 1.5 to 8.5 (4 runs). Within one process a gain built twice is still compiled once, and gain objects made in the parent keep working in a forked child; a child that builds a gain its parent has already built compiles it again, since it no longer shares the parent's cache. Not run on Windows, where `mclapply()` does not fork.

---

<a name="ENV03_power"></a>
## ENV03_power. Hypothesis names are ignored, so a graph named in another order is evaluated as a different graph

- Functions: calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (the group sequential functions on gsd-build only)
- Potential fix: tested (patches 5, 66)

**What the error is.** Names on `hyp_weight`, on the rows and columns of `trans_matrix` and on the columns of `pvals` are never compared: everything is matched by position. In the script the p-value columns are OS, PFS, ORR, and the graph is written, consistently, in the order ORR, OS, PFS. ORR's weight and edges are applied to the OS p-values, and the local power comes back as 0.823, 0.767, 0.650 where the graph as named gives 0.876, 0.760, 0.630. There is no message, and the numbers are plausible. A matrix reordered without its weights is accepted in the same way by `is_graph_valid()` and `calc_power_pvals_gsd()`, and `graph_optimise()` returns weights that carry the names of a constraint written in another order than the p-value columns.

**What causes it.** No function compares the names. `calc_power_pvals()` hands `hyp_weight` and `trans_matrix` to the kernel as they come (`R/calc_power.R:147-152`), as does `calc_power_pvals_gsd()` (`R/calc_power_gsd.R:146-152`), and `is_graph_valid()` checks dimensions and values only (`R/utils.R:128-198`). The kernel indexes by position.

**Code showing the problem** ([`reprex/ENV03_power.R`](reprex/ENV03_power.R)):

```r
# ENV03_power: hypothesis names are ignored; a graph named in another order is evaluated as a different graph
# Run: Rscript ENV03_power.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 20000)
colnames(pvals) <- c("OS", "PFS", "ORR")

w <- c(OS = 0.6, PFS = 0.3, ORR = 0.1)
G <- rbind(OS  = c(OS = 0,   PFS = 0.7, ORR = 0.3),
           PFS = c(OS = 0.4, PFS = 0,   ORR = 0.6),
           ORR = c(OS = 0.5, PFS = 0.5, ORR = 0))
cat("columns of pvals:               ", colnames(pvals), "\n")
cat("graph written as OS, PFS, ORR:  ", calc_power_pvals(pvals, w, G)$local_power, "\n")

ord <- c("ORR", "OS", "PFS")          # the same graph, written in another order
cat("graph written as ORR, OS, PFS:  ", calc_power_pvals(pvals, w[ord], G[ord, ord])$local_power, "\n")
cat("EXPECTED: the first line of numbers again (matched by name), or an error that the names disagree\n")
```

Output on `gsd-build`:

```
columns of pvals:                OS PFS ORR
graph written as OS, PFS, ORR:   0.87605 0.75965 0.62975
graph written as ORR, OS, PFS:   0.82315 0.7672 0.64985
EXPECTED: the first line of numbers again (matched by name), or an error that the names disagree
```

**Potential fix.** Keep matching by position and refuse the one case that can only be a mistake: the same set of names in a different order. A helper in `R/utils.R`, called by the three functions with `names(hyp_weight)`, `rownames(trans_matrix)`, `colnames(trans_matrix)` and the hypothesis names of the p-values:

```r
.check_name_order <- function(..., call = rlang::caller_env()) {
    sets <- Filter(function(nm) !is.null(nm) && !anyNA(nm) && all(nzchar(nm)), list(...))
    for (i in seq_along(sets)) {
        for (j in seq_len(i - 1L)) {
            first <- sets[[j]]
            second <- sets[[i]]
            if (length(first) == length(second) && !identical(first, second) &&
                    identical(sort(first), sort(second))) {
                cli::cli_abort(c(
                    "{.code {names(sets)[[j]]}} and {.code {names(sets)[[i]]}} \\
                    hold the same hypothesis names in a different order.",
                    i = "Hypotheses are matched by position, never by name."
                ), call = call)
            }
        }
    }
    invisible(NULL)
}
```

With this change the second call of the script stops: "`names(hyp_weight)` and `colnames(pvals)` hold the same hypothesis names in a different order". Unnamed, partly named and unrelated names pass as before. Patch 66 calls the helper in both optimisers too, on the names of the constraint and of start graphs. Matching by name is the alternative; the patch states "matched by position" in the help pages.

---

<a name="ENV03_spending"></a>
## ENV03_spending. A spending list named in another order is applied by position, and summary() prints its names in the wrong rows

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patches 22, 70)

**What the error is.** This is the transform's share of ENV03 (names are ignored, everything is matched by position). A user writes `spending = list(H3 = sfLDPocock, H1 = sfLDOF, H2 = sfLDOF)`, meaning Pocock-type spending for H3. The list is applied by position, so H1 is tested with the Pocock-type function: its interim boundary at the full level is 0.0155 where 0.0015 was meant, and H3 gets 0.0015. `summary()` prints the list names as labels, so the row for H1 reads "H3". No message is given. The same happens when the p-value array names its hypotheses (OS, PFS, ORR) and the list uses those names in another order.

**What causes it.** `.gsd_spending_list()` checks that the list holds `m` functions and returns it as it is (`R/transform_pvalues_gsd.R:616-637`); its names are never compared with anything. `.gsd_spending_labels()` then returns the same names as labels (lines 644-646).

**Code showing the problem** ([`reprex/ENV03_spending.R`](reprex/ENV03_spending.R)):

```r
# ENV03 (spending list): a spending list named in another order is applied by position
# Run: Rscript ENV03_spending.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8, 0.7), info_frac = c(0.5, 1), nsim = 1000)

# Meant: Pocock-type spending for H3, O'Brien-Fleming type for H1 and H2.
spending <- list(H3 = sfLDPocock, H1 = sfLDOF, H2 = sfLDOF)
pv <- transform_pvalues_gsd(raw, spending = spending)

s <- capture.output(summary(pv))
cat(s[grep("^ *hypothesis", s) + 0:3], sep = "\n")
interim <- sapply(pv$tables, function(tab) tab$bounds[nrow(tab$bounds), 1])
cat("interim nominal boundary at the full level, H1 H2 H3:", round(interim, 5), "\n")
cat("EXPECTED: 0.00153 0.00153 0.0155 (matched by name), or an error that the names",
    "are in another order\n")
```

Output on `gsd-build`:

```
 hypothesis analyses matured_at look_back spending
         H1     1, 2          2     FALSE       H3
         H2     1, 2          2     FALSE       H1
         H3     1, 2          2     FALSE       H2
interim nominal boundary at the full level, H1 H2 H3: 0.0155 0.00153 0.00153
EXPECTED: 0.00153 0.00153 0.0155 (matched by name), or an error that the names are in another order
```

**Potential fix.** Refuse a list whose names are the hypothesis names in a different order. The names compared are those of the second dimension of `pvals`, or H1, H2, ... when it has none. In `.gsd_spending_list()`, which now receives `hyp_names = dimnames(pvals)[[2L]]`:

```r
given <- names(spending)
expected <- hyp_names %||% .gsd_hyp_labels(m)      # rlang's %||%
if (
    !is.null(given) &&
        !anyDuplicated(given) &&
        setequal(given, expected) &&
        !identical(given, expected)
) {
    cli::cli_abort(
        c(
            "The names of {.arg spending} are the hypothesis names \\
            in a different order.",
            x = "{.arg spending} is named {.val {given}}; the \\
            hypotheses are {.val {expected}}.",
            i = "The list is matched to the hypotheses by position, \\
            not by name: reorder it, or remove its names."
        ),
        call = call
    )
}
```

With this change the script stops at `transform_pvalues_gsd()` with that message. An unnamed list, a list named in the order of the hypotheses and a list with other names are used as before. Judgement call: an error was preferred to matching by name, since the rest of the package matches by position.

---

<a name="ENV04"></a>
## ENV04. A local search on all rows depends on the session seed, and changes it

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 50)

**What the error is.** `graph_optimise(global_search = FALSE)` on all rows is a deterministic search: same data, same start graph, no random step. It still returns a different graph for each session seed (weights 0.5916, 0.5765 and 0.6121 on H1 for seeds 1, 2 and 3 in the script) and advances `.Random.seed`. The second face: `control_global(seed = 99)` does not make a run reproducible once the global stage subsamples, the default above 50,000 rows; two session seeds gave gains 0.925083 and 0.925442 on 60,000 rows.

**What causes it.** `.sample_pvals_rows()` permutes the rows with the session generator even when `nsim` equals the number of rows (`R/optimisation.R:269-275`; `.sample_pvals_gsd()` at `R/optimisation_gsd.R:353-360`). The permutation changes the order in which the gain is summed, so the objective differs in its last digits (about 5e-16 here), which is enough to send COBYLA down another path on a piecewise constant objective. For the second face, the global stage draws its subsample (`R/optimisation.R:314`) before `GA::ga()` applies the user's seed.

**Code showing the problem** ([`reprex/ENV04.R`](reprex/ENV04.R)):

```r
# ENV04: a local search on all rows depends on the session seed, and changes it
# Run: Rscript ENV04.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(3)
P <- simulate_pvalues(c(0.85, 0.8, 0.6), nsim = 3000)
gain <- trial_success(0.3 * r1 + 0.7 * r2 + 0.3 * (r2 && r3), verbose = "silent")

# No global search and nsim_local unset: every row is used and nothing in the search is random.
for (seed in 1:3) {
    set.seed(seed)
    before <- .Random.seed
    res <- graph_optimise(P, graph_constraint_free(3), gain, global_search = FALSE, verbose = "silent")
    cat("set.seed(", seed, "): weights ", paste(sprintf("%.4f", res$hyp_weight), collapse = " "),
        "  gain ", sprintf("%.6f", res$power$trial_success),
        "  .Random.seed ", if (identical(before, .Random.seed)) "unchanged" else "changed", "\n", sep = "")
}
cat("EXPECTED: three identical lines, and .Random.seed unchanged\n")
```

Output on `gsd-build`:

```
set.seed(1): weights 0.5916 0.4084 0.0000  gain 0.924067  .Random.seed changed
set.seed(2): weights 0.5765 0.4235 0.0000  gain 0.924133  .Random.seed changed
set.seed(3): weights 0.6121 0.3879 0.0000  gain 0.922700  .Random.seed changed
EXPECTED: three identical lines, and .Random.seed unchanged
```

**Potential fix.** Return the p-values untouched, drawing no random number, when every row is wanted, and draw the subsample of the global stage under the seed the user gave the genetic algorithm.

```r
.sample_pvals_rows <- function(pvals, nsim, seed = NULL) {
    if (nsim >= nrow(pvals)) {
        return(pvals)
    }
    idx <- if (is.null(seed)) {
        sample.int(nrow(pvals), size = nsim, replace = FALSE)
    } else {
        withr::with_seed(seed, sample.int(nrow(pvals), size = nsim, replace = FALSE))
    }
    pvals[idx, , drop = FALSE]
}

# in .graph_optimise_ga()
pvals_sampled <- .sample_pvals_rows(pvals, nsim, seed = global_opts[["seed"]])
```

`.sample_pvals_gsd()` gets the same two changes. With this change the script prints three identical lines (weights 0.5772 0.4228 0.0000) with the seed unchanged, and the two seeded runs on 60,000 rows agree. Results for a given session seed change once, since the genetic algorithm no longer finds the generator advanced by the shuffle. `withr` is already in Imports.

---

<a name="MEM1"></a>
## MEM1. The serial kernels compute matrix offsets in 32-bit integers, which overflow above 2^31 p-values

- Functions: calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise() and graph_optimise_gsd() with num_threads = 1
- Branches: main and gsd-build (the group sequential kernel on gsd-build only)
- Potential fix: tested (patch 7)

**What the error is.** The two serial kernels compute the position of a p-value in its matrix as `set + i * N` in `int`. Once the matrix has more than 2^31 - 1 elements, for example 1e8 trials of 22 hypotheses (17.6 GB), the sum overflows: for the last p-value the offset 2,199,999,999 becomes -2,094,967,297 under the usual wrap-around, and the kernel would read in front of the p-value matrix and write in front of its output. This was found by reading and not run, since it needs more memory than the 7 GB test machine has; the script prints the declarations and does the arithmetic. The parallel kernels are not affected: they index through `RMatrix`, whose offsets are `std::size_t`.

**What causes it.** `const int N = pvals.nrow();` and `for (int set = 0; set < N; ++set)` (`src/graph_shortcut.cpp:66, 94`; `src/graph_shortcut_gsd.cpp:68, 106`). The read at `src/graph_shortcut.cpp:101` and the write at `:112`, and in the group sequential kernel the read at `:119` and the writes at `:129-130`, therefore form their offsets in `int`. Signed overflow is undefined behaviour in C++.

**Code showing the problem** ([`reprex/MEM1.R`](reprex/MEM1.R)):

```r
# MEM1: the serial kernels compute matrix offsets in 32-bit integers
# Run from the repository root: Rscript MEM1.R   (reads src/graph_shortcut.cpp; allocates nothing)
# fmt: skip file
src <- trimws(readLines("src/graph_shortcut.cpp"))
cat("in graph_shortcut(), the serial fixed-sample kernel:\n")
for (pattern in c("N = pvals.nrow()", "; set < ", "p_ptr[set", "h_ptr[set")) {
    cat("   ", grep(pattern, src, fixed = TRUE, value = TRUE)[1], "\n")
}

n_trials <- 1e8                           # 1e8 trials of 22 hypotheses: 2.2e9 p-values, 17.6 GB
n_hyp <- 22
offset <- (n_trials - 1) + (n_hyp - 1) * n_trials      # `set + i * N` for the last p-value
as_int <- (offset + 2^31) %% 2^32 - 2^31               # the same sum in a 32-bit signed integer
cat("offset of the last p-value:      ", format(offset, big.mark = ",", scientific = FALSE), "\n")
cat("the same sum in a 32-bit integer:", format(as_int, big.mark = ",", scientific = FALSE), "\n")
cat("EXPECTED: `N` and `set` declared as R_xlen_t (64 bits), so that the offset cannot overflow\n")
```

Output on `gsd-build`:

```
in graph_shortcut(), the serial fixed-sample kernel:
    const int N = pvals.nrow();
    for (int set = 0; set < N; ++set) {
    cur_p[i] = p_ptr[set + i * N];
    h_ptr[set + i * N] = 1;   // TRUE in R's logical representation
offset of the last p-value:       2,199,999,999
the same sum in a 32-bit integer: -2,094,967,297
EXPECTED: `N` and `set` declared as R_xlen_t (64 bits), so that the offset cannot overflow
```

**Potential fix.** Declare the row count and the trial index as `R_xlen_t` in the two serial functions, and build the outputs from `pvals.nrow()` so that nothing is narrowed:

```diff
-  const int N = pvals.nrow();
+  const R_xlen_t N = pvals.nrow();
   const int m = pvals.ncol();
@@
-  LogicalMatrix h(N, m);  // zero-initialised by R
+  LogicalMatrix h(pvals.nrow(), m);  // zero-initialised by R
@@
-  for (int set = 0; set < N; ++set) {
+  for (R_xlen_t set = 0; set < N; ++set) {
```

The same three changes go into `graph_shortcut_gsd()`. Run from the fixed tree, the script prints the `R_xlen_t` declarations; the loop line reads `set = block; set < block_end` there, since patch 12 (MEM3) runs the loop in blocks. No test in the series allocates a matrix above the limit, so the overflow itself remains unexercised. Below the limit, 160 kernel outputs on 40 random graphs were identical on the two builds.
