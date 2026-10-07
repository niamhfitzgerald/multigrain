# Severity 1: a wrong number or a crash, with no warning

The package returns a number that is wrong, or the R session ends, and nothing tells the user.

7 entries. Back to the [index](README.md).

Contents: [A1](#A1), [A2](#A2), [A3](#A3), [A4](#A4), [A5](#A5), [ST1](#ST1), [ENV01](#ENV01)

---

<a name="A1"></a>
## A1. A gain that is negative for every graph is not optimised

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patches 46, 67)

**What the error is.** With 3 or more hypotheses and a gain that is below zero for every graph (value minus cost, a regret scale), the optimisers return a poor graph as "optimal". In the script only H3 has power and the gain is `r3 - 2`: all alpha on H3 gives -1.113, yet `graph_optimise()` returns weights 1 0 0 with gain -1.9525, worse than the default start graph (-1.208). There is no warning and `graph_valid` is `TRUE`. `?trial_success` says the graph that maximises psi also maximises psi + 5. `graph_optimise_gsd()` does the same. A local-only search finds 0 0 1 here, but with `r1 + r2 + r3 - 3` and powers 0.9, 0.8, 0.7 it returned -0.744, below its start graph (-0.741).

**What causes it.** For a parameter vector that decodes outside the feasible region, the objective closure returns minus the size of the violation (`R/objective_function.R:50-64`, `R/objective_function_gsd.R:59-73`), for example -1e-07. That is a penalty only while real gains are positive. When every graph scores below zero, a point just outside the region beats them all and the search settles there; `repair_graph()` then clamps that point back into a graph.

**Code showing the problem** ([`reprex/A1.R`](reprex/A1.R)):

```r
# A1: a gain that is negative for every graph is not optimised
# Run: Rscript A1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.05, 0.05, 0.90), nsim = 2000)   # only H3 has power
gain <- trial_success(0 * r1 + 0 * r2 + r3 - 2, verbose = "silent")

G <- matrix(0.5, 3, 3)
diag(G) <- 0
value <- function(w) calc_power_pvals(P, w, G, custom_power = list(g = gain))$g
cat("gain of the default start graph, weights 1/3 1/3 1/3:", value(rep(1, 3) / 3), "\n")
cat("gain with all alpha on H3,       weights 0 0 1      :", value(c(0, 0, 1)), "\n")

ctrl <- control_global(multigrain_control(), popSize = 60, maxiter = 50, run = 20)
set.seed(2)
res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")
cat("graph_optimise() returns weights", round(unname(res$hyp_weight), 3),
    "with gain", res$power$trial_success, "\n")

# The reason: the score the search sees for a point just outside the feasible region
obj <- multigrain:::create_obj_func(3, gain$func, rep(NA_real_, 3), `diag<-`(matrix(NA_real_, 3, 3), 0), P)
cat("objective at free weights (1, 1e-7), which make the third weight -1e-7:",
    obj(c(1, 1e-7, 0.5, 0.5, 0.5)), "\n")
cat("EXPECTED: weights 0 0 1 with gain -1.113, and an infeasible point scored below every graph\n")
```

Output on `gsd-build`:

```
gain of the default start graph, weights 1/3 1/3 1/3: -1.208
gain with all alpha on H3,       weights 0 0 1      : -1.113
graph_optimise() returns weights 1 0 0 with gain -1.9525
objective at free weights (1, 1e-7), which make the third weight -1e-7: -1e-07
EXPECTED: weights 0 0 1 with gain -1.113, and an infeasible point scored below every graph
```

**Potential fix.** Add an offset to every penalty branch, set once from the gain of the default start graph when the closure is created. In `create_obj_func()` and `create_obj_func_gsd()`:

```r
if (any(hyp_weight < 0)) {
    return(penalty_base + sum(hyp_weight[hyp_weight < 0]))
}
# ... the same offset in the other four penalty branches

# after the closure is defined: one evaluation at the default start graph
.obj_penalty_base <- function(obj_func, hyp_constraint, trans_constraint) {
    x_ref <- create_start_params(list(
        hyp_constraint = hyp_constraint,
        trans_constraint = trans_constraint
    ))
    u_ref <- obj_func(x_ref)
    if (!is.finite(u_ref) || u_ref >= 0) {
        return(0)
    }
    u_ref - max(1, abs(u_ref))
}
```

With this change the script returns weights 0 0 1 with gain -1.113, and the infeasible point scores -2.416. The offset is exactly 0 when the reference gain is not negative, so nothing changes for a positive gain; the cost is one extra evaluation per closure. Patch 67 adds `.obj_penalty_below_start()`, which lowers the offset when a local-only search starts from a user's graph that scores below the default one; since patch 73 (entry B1) such a graph is no longer the start, so it is a safeguard only.

---

<a name="A2"></a>
## A2. A gain written for more hypotheses than the p-values have is evaluated outside the rejection matrix

- Functions: calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (the group sequential variant on gsd-build only)
- Potential fix: tested (patches 1, 2, 68)

**What the error is.** `calc_power_pvals()` accepts a compiled gain that refers to a hypothesis the p-value matrix does not have, for example `r1 + r2 + r3 + r4` with 3 columns. The value returned is whatever lies in memory behind the rejection matrix: about 321,000,000 in one run for a gain that cannot exceed 4, and another number in the next run. With `r1 + r99` on 200,000 rows the R session ends with a segmentation fault. A gain kept from a larger design and reused on a smaller one is enough to get there. `calc_power_pvals_gsd()` has a check, but a second `custom_power` entry with the same name as the first escapes it: with gains built by `trial_success()`, `list(a = <gain for 2>, a = <gain for 4>)` on 2 hypotheses returned -222,639,715 in one run (a gain built by `trial_success_gsd()` is stopped there by a width test in its own compiled code).

**What causes it.** `calc_power_pvals()` never compares the gain's `m` with `ncol(pvals)` (`R/calc_power.R:145-152`), and `.eval_custom_power()` hands the rejection matrix to the compiled function (`R/calc_power.R:248`), which indexes `x(i, j)` without a column check (`R/trial_success.R:298-304`). `graph_optimise()` does compare (`R/optimisation.R:146`). In `calc_power_pvals_gsd()` the loop at `R/calc_power_gsd.R:135-144` looks each entry up by name, and `custom_power[[nm]]` returns the first entry of that name both times.

**Code showing the problem** ([`reprex/A2.R`](reprex/A2.R)):

```r
# A2: calc_power_pvals() evaluates a gain written for more hypotheses than the p-values have
# Run: Rscript A2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)        # 3 hypotheses
gain4 <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")   # written for 4
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2

val <- calc_power_pvals(pvals, w, G, custom_power = list(gain = gain4))$gain
cat("value of r1 + r2 + r3 + r4 on 3 hypotheses:", format(val, big.mark = ","), "\n")
cat("possible (between 0 and 4):", val >= 0 && val <= 4, "\n")

# A gain with a far larger index ends the R session, so the call is made in a
# child process.
code <- 'library(multigrain)
set.seed(1)
pvals <- simulate_pvalues(c(0.8, 0.8), nsim = 2e5)
gain99 <- suppressWarnings(trial_success(r1 + r99, verbose = "silent"))
calc_power_pvals(pvals, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2), custom_power = list(gain = gain99))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with r1 + r99 on 2 hypotheses: exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an error from calc_power_pvals(), since the gain refers to a hypothesis the p-values do not have\n")
```

Output on `gsd-build`:

```
value of r1 + r2 + r3 + r4 on 3 hypotheses: 320,501,453
possible (between 0 and 4): FALSE
child process with r1 + r99 on 2 hypotheses: exit status 139 (139 = segmentation fault)
EXPECTED: an error from calc_power_pvals(), since the gain refers to a hypothesis the p-values do not have
```

**Potential fix.** Check every entry by position before the kernel runs. In `R/calc_power.R`, called as `.check_custom_power_dims(custom_power, m = ncol(pvals), call = call)`:

```r
.check_custom_power_dims <- function(custom_power, m, call = rlang::caller_env()) {
    nms <- names(custom_power)
    for (i in seq_along(custom_power)) {
        item <- custom_power[[i]]
        if (is_trial_success(item) && isTRUE(item$m > m)) {
            arg <- paste0("custom_power$", nms[[i]])
            cli::cli_abort(c(
                "{.arg {arg}} refers to more hypotheses than {.arg pvals} has.",
                x = "The trial success function is defined over \\
                m = {item$m}, but the p-values hold m = {m}."
            ), call = call)
        }
    }
    invisible(NULL)
}
```

With this change the script stops at the first call with that message. The loop in `calc_power_pvals_gsd()` becomes `for (i in seq_along(custom_power))`, and patch 68 makes the generated C++ itself stop when `x.ncol()` is below the gain's `m`. A gain over fewer hypotheses than the p-values is still accepted by `calc_power_pvals()`.

---

<a name="A3"></a>
## A3. Index 0 is accepted in a gain and reads outside the matrix

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: tested (patch 30)

**What the error is.** `r0` and `t0` are accepted as symbols. The compiled gain then reads column -1 of the matrix it is given, which is memory in front of the matrix. With `trial_success()` the value returned depends on what happens to be there: it can look plausible, as below, or be in the hundreds of millions. With `trial_success_gsd()` a discount table indexed by that memory ends the R session.

**What causes it.** The symbol pattern `^r\d+$` admits 0 (`R/trial_success.R:255, 523`; `R/trial_success_gsd.R:910`), as do `^[rt]\d+$` and `^t\d+$` in the group sequential parser (`R/trial_success_gsd.R:605, 917`), and the index is turned into a C++ column by subtracting 1. The number of hypotheses is taken as the largest index, so `r0 + r1 + r2` is stored as a gain over 2 hypotheses and passes the dimension checks of `calc_power_pvals_gsd()` and the optimisers.

**Code showing the problem** ([`reprex/A3.R`](reprex/A3.R)):

```r
# A3: index 0 is accepted in a gain and reads outside the matrix
# Run: Rscript A3.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

g <- trial_success(r0 + r1 + r2, verbose = "silent")
cat("hypotheses the object says it covers:", g$m, "\n")
cat("generated C++:", grep("total \\+=", strsplit(g$cpp_code, "\n")[[1]], value = TRUE), "\n")

rej <- matrix(c(TRUE, TRUE, FALSE, TRUE), 2, 2)   # r1 + r2 has mean 1.5 here
val <- g$func(rej)
cat("value of r0 + r1 + r2:", format(val), "\n")
cat("plausible (between 1.5 and 2.5):", val >= 1.5 && val <= 2.5, "\n")

# The group sequential constructor accepts t0 too; using it ends the R session,
# so the call is made in a child process.
code <- 'library(multigrain)
g <- trial_success_gsd(d(t0) + d(t1) + d(t2), d = c(1, 0.8), verbose = "silent")
g$func(matrix(1L, 100000, 2))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with d(t0): exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an error from both constructors, since hypotheses are numbered from 1\n")
```

Output on `gsd-build`:

```
hypotheses the object says it covers: 2
generated C++:         total += (double(x(i, -1)) + double(x(i, 0)) + double(x(i, 1))); // Apply user-defined function on each row
value of r0 + r1 + r2: 1.5
plausible (between 1.5 and 2.5): TRUE
child process with d(t0): exit status 139 (139 = segmentation fault)
EXPECTED: an error from both constructors, since hypotheses are numbered from 1
```

**Potential fix.** Refuse an index below 1 where the indices are counted, which every gain passes before any C++ is generated. In `count_unique_indices()` (`R/trial_success.R`), and the same in `count_unique_indices_gsd()`:

```r
numeric_indices <- as.integer(indices)

below_one <- unique(all_matches[which(numeric_indices < 1L)])
if (length(below_one) > 0L) {
    cli::cli_abort(c(
        "Hypotheses are numbered from 1 in the trial success expression.",
        x = "{.code {below_one}} {?is/are} not {?a /}rejection \\
        indicator{?s}: the first one is {.code r1}."
    ))
}
```

With this change both constructors stop with that first line; the second line of `trial_success_gsd()` names `r1` and `t1`. Nothing changes for a valid gain.

---

<a name="A4"></a>
## A4. sum_to_one_constraint = FALSE switches off the row-sum check, so a graph can hand out alpha twice

- Functions: is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 3)

**What the error is.** With `sum_to_one_constraint = FALSE`, a transition matrix with a row that sums to more than 1 is reported valid and is evaluated. In the script H1 passes all its alpha to H2 and all of it again to H3 (row sum 2): `is_graph_valid()` returns `TRUE`, and `calc_power_pvals()` reports a probability of rejecting a true null hypothesis of 0.0497 at a one-sided level of 0.025. `calc_power_pvals_gsd()` evaluates the same graph (0.0492 in a run with analyses at information fractions 0.5 and 1 and `gsDesign::sfLDOF`). The flag is needed for any graph with a terminal node, and the help example of `calc_power_pvals()` sets it, so it is switched on routinely. A slip in a hand-written matrix then goes unnoticed, and the power reported belongs to a procedure that does not control the familywise error rate.

**What causes it.** `is_graph_valid()` looks at the row sums only inside `if (sum_to_one_constraint)` (`R/utils.R:189-198`). With the flag off no condition on the row sums is left. The entries are checked one by one to lie in [0, 1] (`R/utils.R:172`), which a row holding two 1s satisfies. The kernels state "row sums must be <= 1" in a comment (`src/graph_shortcut.cpp:54-55`) and do not check it.

**Code showing the problem** ([`reprex/A4.R`](reprex/A4.R)):

```r
# A4: sum_to_one_constraint = FALSE switches off the row-sum check altogether
# Run: Rscript A4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(1, 0, 0)
G <- rbind(c(0, 1, 1),   # H1 passes all its alpha to H2, and all of it again to H3
           c(0, 0, 0),
           c(0, 0, 0))
cat("row sums of the transition matrix:", rowSums(G), "\n")
cat("is_graph_valid(sum_to_one_constraint = FALSE):",
    is_graph_valid(w, G, sum_to_one_constraint = FALSE), "\n")

set.seed(1)
pvals <- simulate_pvalues(c(0.9999, 0.025, 0.025), nsim = 2e5)   # H2 and H3 are true nulls
out <- calc_power_pvals(pvals, w, G, sum_to_one_constraint = FALSE,
                        custom_power = list(any_null = function(x) x[2] || x[3]))
cat("P(reject a true null) at one-sided alpha 0.025:", round(out$any_null, 4), "\n")
cat("EXPECTED: FALSE with a warning, then an error from calc_power_pvals(): row 1 sums to 2\n")
```

Output on `gsd-build`:

```
row sums of the transition matrix: 2 0 0
is_graph_valid(sum_to_one_constraint = FALSE): TRUE
P(reject a true null) at one-sided alpha 0.025: 0.0497
EXPECTED: FALSE with a warning, then an error from calc_power_pvals(): row 1 sums to 2
```

**Potential fix.** With the flag off, still require every row sum to be at most 1. In `is_graph_valid()`:

```r
row_sums <- rowSums(trans_matrix)
if (sum_to_one_constraint) {
    if (anyNA(row_sums) || any(abs(row_sums - 1) > tolerance)) {
        warning(
            "One or more rows of `trans_matrix` do not sum to 1 within tolerance.",
            call. = FALSE
        )
        return(FALSE)
    }
} else if (anyNA(row_sums) || any(row_sums - 1 > tolerance)) {
    warning(
        "One or more rows of `trans_matrix` sum to more than 1.",
        call. = FALSE
    )
    return(FALSE)
}
```

With this change `is_graph_valid()` returns `FALSE` with the second warning, and both power functions stop with "do not build a valid graph". Rows that sum to 1 or less are evaluated as before.

---

<a name="A5"></a>
## A5. An information fraction above 1 with an uncapped spending function spends more than alpha

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patches 19, 65, 70)

**What the error is.** A spending function written in plain R, such as `function(alpha, t) alpha * t`, is documented as supported, and a final analysis that over-runs to an information fraction of 1.2 is accepted by design (`dev/gsd_design_record.md:287`). Together they spend 0.030 of a level of 0.025, and `transform_pvalues_gsd()` accepts that without a message. In the script the type I error of one true null hypothesis is 0.030 at a one-sided level of 0.025. A hand-written Hwang-Shih-DeCani function (parameter -4) spends 0.0562 there and gave 0.056 in the same design.

**What causes it.** The only check on a spending function is `.gsd_check_spending()` (`R/transform_pvalues_gsd.R:396-425`). It evaluates the function once, at the full level and an information fraction of 1 (line 405), and compares the result with `alpha`. The fractions a hypothesis is analysed at are never checked, so `.gsd_boundary_table()` hands increments that sum to more than the level to `gsDesign::gsBound1()` (line 347). gsDesign's own spending functions stop rising at a fraction of 1, which is why they are safe.

**Code showing the problem** ([`reprex/A5.R`](reprex/A5.R)):

```r
# A5: an information fraction above 1 with an uncapped spending function spends more than alpha
# Run: Rscript A5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

lin <- function(alpha, t) alpha * t        # hand-written linear spending
info <- c(0.5, 1.2)                        # the final analysis over-runs by 20%
cat("spend of 0.025 at t = 1, the only point the package checks:", lin(0.025, 1), "\n")
cat("cumulative spend of 0.025 at the two analyses:", lin(0.025, info), "\n")

set.seed(1)
raw <- simulate_pvalues_gsd(0.025, info_frac = info, nsim = 2e5)   # one true null hypothesis
pv <- transform_pvalues_gsd(raw, spending = lin, alpha = 0.025)
tab <- pv$tables[[1]]
cat("nominal boundaries at the full level:", signif(tab$bounds[nrow(tab$bounds), ], 4), "\n")

out <- calc_power_pvals_gsd(pv, 1, matrix(0, 1, 1), sum_to_one_constraint = FALSE)
cat("type I error at one-sided alpha 0.025:", out$local_power, "\n")
cat("EXPECTED: an error, since the function spends 0.030 of a level of 0.025;",
    "never a type I error above 0.025\n")
```

Output on `gsd-build`:

```
spend of 0.025 at t = 1, the only point the package checks: 0.025
cumulative spend of 0.025 at the two analyses: 0.0125 0.03
nominal boundaries at the full level: 0.0125 0.02159
type I error at one-sided alpha 0.025: 0.029855
EXPECTED: an error, since the function spends 0.030 of a level of 0.025; never a type I error above 0.025
```

**Potential fix.** Check the spend where it is used: at the fractions each hypothesis is analysed at, and at every level of the grid, since a hypothesis is tested at a share of `alpha`.

```r
# .gsd_check_spend_path(), called before the table is built (messages shortened)
spent <- .gsd_spend(spending, alpha = alpha, t_look = t_look, hyp = hyp, call = call)
over <- which(spent > alpha + 1e-6 * alpha)
if (length(over) > 0L) {
    cli::cli_abort("Spending function for hypothesis {hyp} spends more than the level.")
}
if (any(diff(c(0, spent)) < 0)) {
    cli::cli_abort("Spending function for hypothesis {hyp} does not return a cumulative spend.")
}

# .gsd_boundary_table(), inside the loop over the levels of the grid
level <- grid_levels[[g]]
if (max(cum_spend) > level * (1 + 1e-4) + 1e-15) {
    cli::cli_abort("Spending function for hypothesis {hyp} spends more than the level.")
}
```

With this change the script stops at `transform_pvalues_gsd()` with the amounts spent and the advice to use `pmin(t, 1)`. gsDesign's functions and a capped hand-written function are still accepted with a fraction of 1.2. The slack of 1e-4 is a judgement call: with 1e-6 the classical O'Brien-Fleming function of `dev/review/gsd_user_testing/07_features.R` was refused. The alternative to an error is to cap the spend at the level silently.

---

<a name="ST1"></a>
## ST1. A flat stretch of the boundary table is inverted from its lower end, so a hypothesis is rejected with nothing left to spend

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 18)

**What the error is.** A spending function that caps the interim spend in absolute terms, such as `function(a, t) ifelse(t < 1, pmin(a, 0.01), a)`, meets every documented requirement. A hypothesis holding a level of 0.00975 spends all of it at the interim, yet a final p-value of 1e-4 gets a repeated p-value of 0.0080 and is rejected. In the script the exact type I error of that hypothesis is 0.009905, which is 1.016 times its level. The round 2 report measured a familywise error rate of 0.02534 at 0.025 (three true nulls, 4 seeds of 8 million trials); that figure is quoted from the report, not reproduced by the script.

**What causes it.** `.gsd_invert()` drops repeated boundaries with `keep <- !duplicated(bounds) & bounds > 0` (`R/transform_pvalues_gsd.R:365`), which keeps the lowest grid level of a run of equal boundaries; lines 378-385 interpolate from it. Here the final boundary is the same at every level up to 0.01, so a p-value above it is given a level inside the flat stretch, where the boundary is still below the p-value. The design record prescribes this step (`dev/gsd_design_record.md:117`).

**Code showing the problem** ([`reprex/ST1.R`](reprex/ST1.R)):

```r
# ST1: a flat stretch of the boundary table is inverted from its lower end
# Run: Rscript ST1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# The interim may spend up to 0.01 of the level a hypothesis holds; the final gets the rest.
cap <- function(a, t) ifelse(t < 1, pmin(a, 0.01), a)
info <- c(0.5, 1)
level <- 0.39 * 0.025                      # a hypothesis with weight 0.39 at alpha 0.025
cat("level:", level, "  cumulative spend at the two analyses:", cap(level, info), "\n")

# One hypothesis, interim p-value 1, a grid of final p-values.
p2 <- 10^seq(-8, -2, length.out = 20000)
raw <- array(1, dim = c(length(p2), 1, 2))
raw[, 1, 2] <- p2
rp <- transform_pvalues_gsd(raw, info_frac = info, spending = cap)$pvals[, 1, 2]

cat("repeated p-value of a final p-value of 1e-4:", signif(rp[which.min(abs(p2 - 1e-4))], 4), "\n")
thr <- max(c(0, p2[rp < level]))           # largest final p-value rejected at this level
cat("largest final p-value rejected at level", level, ":", signif(thr, 4), "\n")

# Exact type I error: reject at the interim (p1 < level) or at the final (p2 < thr).
z <- qnorm(c(level, thr), lower.tail = FALSE)
rho <- sqrt(info[1] / info[2])
err <- 1 - mvtnorm::pmvnorm(upper = z, corr = matrix(c(1, rho, rho, 1), 2))[1]
cat("exact type I error of the hypothesis:", signif(err, 5),
    "=", round(err / level, 4), "x its level\n")
cat("EXPECTED: no final p-value rejected at this level, since nothing is left to spend;",
    "type I error 0.00975\n")
```

Output on `gsd-build`:

```
level: 0.00975   cumulative spend at the two analyses: 0.00975 0.00975
repeated p-value of a final p-value of 1e-4: 0.00801
largest final p-value rejected at level 0.00975 : 0.0004038
exact type I error of the hypothesis: 0.009905 = 1.0159 x its level
EXPECTED: no final p-value rejected at this level, since nothing is left to spend; type I error 0.00975
```

**Potential fix.** Keep both ends of each run of equal boundaries, so that `approx()` interpolates to the right of a tie from the last level of the run. In `.gsd_invert()`:

```r
distinct <- !duplicated(bounds) & bounds > 0
# (the existing "fewer than two distinct boundaries" check now uses `distinct`)
keep <- which(
    (distinct | !duplicated(bounds, fromLast = TRUE)) & bounds > 0
)
keep <- keep[order(bounds[keep])]

out <- exp(
    stats::approx(
        log(bounds[keep]),
        log(grid[keep]),
        xout = log(p),
        rule = 1,
        ties = "ordered"
    )$y
)
```

With this change the script prints a repeated p-value of 0.0102 and a type I error equal to the level. A table without repeated boundaries gives `approx()` the same points as before, so its output is unchanged. For `sfLDOF`, only raw p-values below about 5e-15 changed in the designs tried, all upwards: at the first analysis, and at the second too when the first is at 10% of the information (entry C5).

---

<a name="ENV01"></a>
## ENV01. A decimal comma in the session changes the gain that is compiled, with no message

- Functions: trial_success(); trial_success_gsd() fails with an unrelated error
- Branches: main and gsd-build
- Potential fix: tested (patches 28, 29)

**What the error is.** With `options(OutDec = ",")`, which a user sets to print decimal commas, `trial_success((r1 || r2) + 0.5 * r3)` is compiled as `5 * r3`. With all three hypotheses rejected it returns 5 where the answer is 1.5. The object prints the correct objective, so only the stored C++ shows the change, and an optimiser given this gain maximises `5 * r3`. A numeric locale with a decimal comma (`LC_NUMERIC`) does the same to a gain given as a string; typed as an expression it stops with "unexpected ','", and `trial_success_gsd()` stops with "missing value where TRUE/FALSE needed".

**What causes it.** `parse_and_transform()` writes a constant with `as.character()` and appends `.0` when it finds no point (`R/trial_success.R:543-546`). `as.character()` follows `OutDec` and the numeric locale, so `0.5` becomes `0,5.0`. In C++ that comma is the comma operator: everything to its left is evaluated and dropped, and `5.0` remains. The formatter of `trial_success_gsd()` uses `sprintf()` (`R/trial_success_gsd.R:936-948`), which ignores `OutDec` but not the locale: its `as.numeric()` check then compares with `NA`.

**Code showing the problem** ([`reprex/ENV01.R`](reprex/ENV01.R)):

```r
# ENV01: a decimal comma in the session changes the gain that is compiled
# Run: Rscript ENV01.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- matrix(TRUE, 1, 3)        # all three rejected: (r1 || r2) + 0.5 * r3 is 1.5

old <- options(OutDec = ",")   # a session that prints decimal commas
g <- trial_success((r1 || r2) + 0.5 * r3, verbose = "silent")
options(old)
cat("built under options(OutDec = \",\")\n")
cat("  objective stored in the object:", g$objective, "\n")
cpp <- grep("total \\+=", strsplit(g$cpp_code, "\n")[[1]], value = TRUE)
cat("  compiled C++:", trimws(sub(";.*", "", cpp)), "\n")
cat("  value when all three are rejected:", g$func(x), "  (correct: 1.5)\n")

# The same defect through the numeric locale, if this machine has one with a comma
for (loc in c("de_DE.UTF-8", "de_DE", "fr_FR.UTF-8", "German_Germany.utf8", "German")) {
    suppressWarnings(Sys.setlocale("LC_NUMERIC", loc))
    if (sprintf("%.1f", 0.5) == "0,5") break
}
if (sprintf("%.1f", 0.5) == "0,5") {
    g2 <- trial_success("(r1 || r2) + 0.5 * r3", verbose = "silent")
    invisible(Sys.setlocale("LC_NUMERIC", "C"))
    cat("built from a string under LC_NUMERIC =", loc, "\n")
    cat("  value when all three are rejected:", g2$func(x), "  (correct: 1.5)\n")
} else {
    cat("LC_NUMERIC part not run: no locale with a decimal comma is installed on this machine\n")
}
cat("EXPECTED: 1.5 from every gain, whatever the session prints\n")
```

Output on `gsd-build`:

```
built under options(OutDec = ",")
  objective stored in the object: (r1 || r2) + 0.5 * r3
  compiled C++: total += (std_min(double(1), double(x(i, 0)) + double(x(i, 1))) + 0,5.0 * double(x(i, 2)))
  value when all three are rejected: 5   (correct: 1.5)
built from a string under LC_NUMERIC = de_DE.UTF-8
  value when all three are rejected: 5   (correct: 1.5)
EXPECTED: 1.5 from every gain, whatever the session prints
```

**Potential fix.** Write every constant with one formatter that does not depend on the session, and compile expressions from the captured values and not from their deparsed text. The formatter (`R/trial_success_gsd.R`), now used by both constructors:

```r
.gsd_gain_cpp_number <- function(x) {
    dec <- Sys.localeconv()[["decimal_point"]]
    fmt <- function(digits) {
        sub(dec, ".", sprintf("%.*g", digits, x), fixed = TRUE)
    }
    txt <- fmt(15L)
    for (digits in 16:17) {
        if (as.numeric(txt) == x) {
            break
        }
        txt <- fmt(digits)
    }
    if (!grepl("[.eE]", txt)) {
        txt <- paste0(txt, ".0")
    }
    txt
}

# parse_and_transform(), R/trial_success.R
txt <- .gsd_gain_cpp_number(node)
```

With this change the script prints 1.5 for both gains (the second checked with a German locale installed). One side effect for valid input: a constant that 15 digits cannot hold is now compiled exactly, so a gain with an injected `1/3` changes by 3.3e-16 and equals plain R.
