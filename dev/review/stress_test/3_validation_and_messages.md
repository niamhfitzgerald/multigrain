# Severity 3: missing or wrong input validation, and messages that point the wrong way

Input that should be refused is accepted, valid input is refused, or the error raised does not lead to the mistake.

32 entries. Back to the [index](README.md).

Contents: [C1](#C1), [C2](#C2), [C3](#C3), [C4](#C4), [C5](#C5), [C6](#C6), [C7](#C7), [C8](#C8), [C9](#C9), [C10](#C10), [C11](#C11), [C12](#C12), [C13](#C13), [C14](#C14), [C15](#C15), [C16](#C16), [C17](#C17), [C18](#C18), [C19](#C19), [C20](#C20), [C21](#C21), [C22](#C22), [C23](#C23), [ENV05](#ENV05), [MEM3](#MEM3), [DOC12](#DOC12), [DOC14](#DOC14), [DOC17b](#DOC17b), [DOC17c](#DOC17c), [DOC17d](#DOC17d), [DOC17f](#DOC17f), [DOC17g](#DOC17g)

---

<a name="C1"></a>
## C1. An analysis that spends nothing aborts the whole transform, with advice that cannot help

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 20)

**What the error is.** This entry covers round 1's C1 and round 2's ST2, one defect reached by two routes. With `gsDesign::sfLDOF` and a first analysis at 5% of the information, `transform_pvalues_gsd()` stops with "The boundary table cannot be inverted" and advises a larger `grid_size`; the script uses four times the default and gets the same error. The same happens with 20 equally spaced analyses (C1) and with gsDesign's functions for "no test at this analysis", `sfTruncated`, `sfTrimmed` and `sfStep` (ST2).

**What causes it.** At such an analysis the cumulative spend is exactly 0 at every level: `sfLDOF(0.025, 0.05)$spend` is 0 in floating point, and the truncated functions return 0 by design. `gsDesign::gsBound1()` gives a zero increment the same boundary (z = 20) at every level, so that column of the table is constant, and `.gsd_invert()` aborts for want of two distinct boundaries (`R/transform_pvalues_gsd.R:365-376`). No grid can make the column vary, so the advice at lines 371-372 cannot help.

**Code showing the problem** ([`reprex/C1.R`](reprex/C1.R)):

```r
# C1 (with ST2): an analysis that spends nothing makes the whole transform abort
# Run: Rscript C1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.05, 0.5, 1)                    # a first look at 5% of the information
cat("sfLDOF cumulative spend of 0.025 at the three analyses:", sfLDOF(0.025, info)$spend, "\n")

set.seed(1)
raw <- simulate_pvalues_gsd(0.9, info_frac = info, nsim = 1000)
pv <- tryCatch(
    transform_pvalues_gsd(raw, spending = sfLDOF, grid_size = 4096),   # 4 times the default
    error = function(e) conditionMessage(e)
)
if (is.character(pv)) {
    cat("transform_pvalues_gsd() stops with:\n", pv, "\n")
} else {
    cat("repeated p-values at analysis 1, range:", range(pv$pvals[, 1, 1]), "\n")
    cat("share below 0.025 at analyses 2 and 3:", colMeans(pv$pvals[, 1, 2:3] < 0.025), "\n")
}
cat("EXPECTED: repeated p-values of 1 at analysis 1 (it cannot reject);",
    "analyses 2 and 3 transformed\n")
```

Output on `gsd-build`:

```
sfLDOF cumulative spend of 0.025 at the three analyses: 0 0.001525323 0.025
transform_pvalues_gsd() stops with:
 The boundary table cannot be inverted.
✖ Fewer than two distinct positive boundaries were found.
ℹ Try a larger `grid_size` or a later information fraction.
EXPECTED: repeated p-values of 1 at analysis 1 (it cannot reject); analyses 2 and 3 transformed
```

**Potential fix.** Leave the repeated p-values of such an analysis at 1, as for an analysis without data, and invert the other columns as before. In `.gsd_transform_hyp()`, where `out` starts as a matrix of 1:

```r
full <- tab$bounds[nrow(tab$bounds), ]
for (l in which(full > .gsd_no_spend_bound())) {
    out[, looks[[l]]] <- .gsd_invert(
        tab$bounds[, l],
        grid = tab$grid,
        p = raw[, looks[[l]]]
    )
}

# the boundary gsBound1() returns for an analysis that is given nothing to spend
.gsd_no_spend_bound <- function() {
    stats::pnorm(
        gsDesign::gsBound1(theta = 0, I = 1, a = -20, probhi = 0)$b,
        lower.tail = FALSE
    )
}
```

With this change the script prints repeated p-values of 1 at analysis 1 and transformed values at analyses 2 and 3. Every design affected stopped with an error before. A repeated information fraction such as `c(0.5, 0.5, 1)` keeps an error, with its own message. Judgement call: the analysis is set to 1 silently; a warning may be wanted.

---

<a name="C2"></a>
## C2. Two analyses with nearly the same information abort with a message that blames the spending function

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patches 24, 65, 70, 72)

**What the error is.** With information fractions `c(0.998, 1)` or `c(0.5, 0.501, 1)`, `transform_pvalues_gsd()` stops with "Spending function for hypothesis 1 is not well ordered" and says the graphical procedure is not valid for it. That is false for `sfLDOF` and `sfLDPocock`, and it sends the user to the wrong argument. A second face: with `c(0.9975, 1)` and `sfLDPocock` the transform is accepted, and a final p-value of 1e-10 gets a repeated p-value of 6.6e-11, smaller than itself.

**What causes it.** `gsDesign::gsBound1()` does not converge at some small levels when two analyses are this close. It sets its `error` element and returns boundaries that are wrong: in the script the final nominal boundary at a level of 5e-12 is 8.5e-11. `.gsd_boundary_table()` keeps only `$b` of the result (`R/transform_pvalues_gsd.R:343-348`), so the flag is never read. The wrong rows make a column non-monotone, and `.gsd_check_well_ordered()` (lines 431-455) reports that as a property of the spending function.

**Code showing the problem** ([`reprex/C2.R`](reprex/C2.R)):

```r
# C2: two analyses with nearly the same information abort with a misleading message
# Run: Rscript C2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.998, 1)                        # two analyses 0.2% of the information apart
set.seed(1)
raw <- array(runif(40), dim = c(20, 1, 2))
msg <- tryCatch(
    {
        transform_pvalues_gsd(raw, info_frac = info, spending = sfLDOF)
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("transform_pvalues_gsd() with sfLDOF says:\n", msg, "\n\n")

# What gsBound1() returns for these analyses at one small level of the table
level <- 5e-12
spend <- sfLDOF(level, info)$spend
fit <- gsBound1(theta = 0, I = info, a = c(-20, -20), probhi = diff(c(0, spend)))
cat("gsBound1() at a level of", level, ": error flag", fit$error,
    ", final nominal boundary", signif(pnorm(fit$b[2], lower.tail = FALSE), 3), "\n")
cat("EXPECTED: an error that names gsBound1() and the two information fractions,",
    "or a transform (sfLDOF is well ordered)\n")
```

Output on `gsd-build`:

```
transform_pvalues_gsd() with sfLDOF says:
 Spending function for hypothesis 1 is not well ordered.
✖ Its nominal boundary at analysis 2 decreases as the allocated level
  increases.
ℹ The group sequential graphical procedure is not valid for such a spending
  function.

gsBound1() at a level of 5e-12 : error flag 1 , final nominal boundary 8.49e-11
EXPECTED: an error that names gsBound1() and the two information fractions, or a transform (sfLDOF is well ordered)
```

**Potential fix.** Read the flag. A flagged level counts as failed only when its boundaries, checked on a finer integration grid, do not spend what was asked, since the flag is also set for some well separated analyses.

```r
# .gsd_boundary_table(), in the loop: `fit` is the whole gsBound1() result
if (fit$error != 0) {
    failed[[g]] <- .gsd_bounds_miss_spend(fit$b, t_look, cum_spend, grid_levels[[g]])
}
# after the loop: abort if any(failed), naming gsBound1() and the closest fractions

.gsd_bounds_miss_spend <- function(b, t_look, cum_spend, level) {
    n_look <- length(t_look)
    crossed <- tryCatch(
        cumsum(gsDesign::gsProbability(
            k = n_look, theta = 0, n.I = t_look,
            a = rep(-20, n_look), b = b, r = 80
        )$upper$prob),
        error = function(cnd) NULL
    )
    if (is.null(crossed) || anyNA(crossed)) {
        return(TRUE)
    }
    max(abs(crossed - cum_spend)) > 1e-2 * level + gsd_grid_min
}
```

With this change the message names `gsBound1()`, the 184 levels that failed and the fractions 0.998 and 1, and suggests `NA` at one of the two. The refusal is kept by choice. The alternative, measured and not adopted, is to compute such tables with `r = 80`. It would also help `c(0.99, 1)`, accepted on both builds, where the final boundary is 1.2% off at a level of 1e-5.

---

<a name="C3"></a>
## C3. A missing p-value at a single full-information analysis stays NA, and the power function then blames the caller

- Functions: transform_pvalues_gsd(), calc_power_pvals_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 21)

**What the error is.** `transform_pvalues_gsd()` turns a missing raw p-value into a repeated p-value of 1 ("cannot reject"), except for a hypothesis that has a single analysis at full information: there `NA` is passed through. In the script one trial has no p-values; the hypothesis with two analyses gets 1 and 1, and the hypothesis analysed once gets 1 and `NA`. `calc_power_pvals_gsd()` then stops and says "`transform_pvalues_gsd()` never emits NA; check how `pvals` was built", which is untrue and points away from the cause. A design with one analysis in all (`info_frac = 1`) passes `NA` through in the same way.

**What causes it.** A hypothesis with one analysis at full information takes a short cut in `.gsd_transform_hyp()` that copies the raw p-values (`R/transform_pvalues_gsd.R:181-184`), since the boundary there is the level itself. Missing values are set to 1 only in `.gsd_invert()` (line 390), which the short cut never calls. The message comes from `R/check_gsd.R:158-163`.

**Code showing the problem** ([`reprex/C3.R`](reprex/C3.R)):

```r
# C3: a missing p-value at a single full-information analysis stays NA
# Run: Rscript C3.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

info <- rbind(c(0.5, 1), c(NA, 1))         # H2 is analysed once, at full information
set.seed(1)
raw <- array(runif(5 * 2 * 2), dim = c(5, 2, 2))
raw[1, , ] <- NA                           # one trial without p-values
pv <- transform_pvalues_gsd(raw, info_frac = info, spending = gsDesign::sfLDOF)
cat("trial 1, H1 (two analyses), repeated p-values:", pv$pvals[1, 1, ], "\n")
cat("trial 1, H2 (one analysis), repeated p-values:", pv$pvals[1, 2, ], "\n")

msg <- tryCatch(
    {
        calc_power_pvals_gsd(pv, c(0.5, 0.5), rbind(c(0, 1), c(1, 0)))
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("calc_power_pvals_gsd() on that object says:\n", msg, "\n")
cat("EXPECTED: 1 1 for both hypotheses (a missing p-value cannot reject) and no error\n")
```

Output on `gsd-build`:

```
trial 1, H1 (two analyses), repeated p-values: 1 1
trial 1, H2 (one analysis), repeated p-values: 1 NA
calc_power_pvals_gsd() on that object says:
 The transformed p-value array contains NA.
✖ The kernel would treat these as never rejectable.
ℹ `transform_pvalues_gsd()` never emits NA; check how `pvals` was built.
EXPECTED: 1 1 for both hypotheses (a missing p-value cannot reject) and no error
```

**Potential fix.** Give the short cut the rule every other path has.

```diff
     if (length(looks) == 1L && t_row[[looks]] >= 1) {
         # the boundary at level a is a itself: nothing to invert
         tab <- NULL
-        out[, seq.int(looks, n_look)] <- raw[, looks]
+        value <- raw[, looks]
+        # a missing p-value is "no data": cannot reject, as in `.gsd_invert()`
+        value[is.na(value)] <- 1
+        out[, seq.int(looks, n_look)] <- value
     } else {
```

With this change the script prints 1 and 1 for both hypotheses and `calc_power_pvals_gsd()` runs. p-values that are not missing are copied unchanged. The alternative is to refuse `NA` in the input of the transform; the patch documents `NA` as "no data" instead.

---

<a name="C4"></a>
## C4. grid_size is accepted down to 2, where the type I error is above the level

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: suggested, not implemented

**What the error is.** `grid_size` sets the number of levels in each boundary table, and any whole number from 2 is accepted. A coarse table is inverted by interpolation between few points, and for `sfLDPocock` the error goes one way: repeated p-values come out too small. In the script (three analyses, a hypothesis at a level of 0.005) the exact type I error is 1.064 times the level at `grid_size = 2`, 1.018 at 8, and 1.000 at 64 and at the default 1024. No message is given. The help examples use 128.

**What causes it.** The only check is `rlang::check_number_whole(grid_size, min = 2)` (`R/transform_pvalues_gsd.R:103`). `.gsd_boundary_table()` spaces that many levels evenly on the log scale between 1e-14 and `alpha` (lines 327-331), and `.gsd_invert()` interpolates linearly between them on the log-log scale (lines 378-385). With 2 levels the whole table is one straight line on that scale.

**Code showing the problem** ([`reprex/C4.R`](reprex/C4.R)):

```r
# C4: grid_size is accepted down to 2, where the type I error is above the level
# Run: Rscript C4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(1, 2, 3) / 3
level <- 0.2 * 0.025                       # a hypothesis with weight 0.2 at alpha 0.025
p <- 10^seq(-8, -1.6, length.out = 50000)  # the same grid of raw p-values at every analysis
raw <- array(rep(p, 3), dim = c(length(p), 1, 3))

for (grid_size in c(2, 8, 64, 1024)) {
    pv <- transform_pvalues_gsd(raw, info_frac = info, spending = sfLDPocock, grid_size = grid_size)
    # largest raw p-value rejected at each analysis, then the exact crossing probability
    thr <- apply(pv$pvals[, 1, ], 2, function(x) max(p[x < level]))
    b <- qnorm(thr, lower.tail = FALSE)
    err <- sum(gsProbability(k = 3, theta = 0, n.I = info, a = rep(-20, 3), b = b)$upper$prob)
    cat(sprintf("grid_size %4d: exact type I error %.6f = %.3f x the level\n",
                grid_size, err, err / level))
}
cat("EXPECTED: a grid_size that puts the type I error above the level is refused\n")
```

Output on `gsd-build`:

```
grid_size    2: exact type I error 0.005319 = 1.064 x the level
grid_size    8: exact type I error 0.005089 = 1.018 x the level
grid_size   64: exact type I error 0.005001 = 1.000 x the level
grid_size 1024: exact type I error 0.005000 = 1.000 x the level
EXPECTED: a grid_size that puts the type I error above the level is refused
```

**Potential fix.** Raise the minimum to a value at which the error is negligible. 64 is suggested, where the script gives 1.000.

```diff
-    rlang::check_number_whole(grid_size, min = 2)
+    rlang::check_number_whole(grid_size, min = 64)
```

This has not been implemented or tested. Seven calls in the package's own tests use 8, 16 or 32 (`tests/testthat/test-transform_pvalues_gsd.R` and `test-graph_shortcut_gsd.R`) and would need a larger value, and the help for `grid_size` should state the minimum. The alternative is a warning below 64 in place of an error. The script prints the same on the build with the other fixes.

---

<a name="C5"></a>
## C5. First-analysis repeated p-values are wrong for raw p-values below about 1e-15

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: suggested, not implemented

**What the error is.** With `gsDesign::sfLDOF` and a first analysis at 10% of the information, a first-analysis p-value of 1e-20 gets a repeated p-value of 0.0017. The exact value, which has a closed form at the first analysis, is 0.0032, so a hypothesis holding a level of 0.002 is rejected where its boundary is not crossed. The ratio to the exact value runs from 0.29 at 1e-25 to 1.00 at 1e-12. Only raw p-values below about 1e-15 are affected, so no error rate can change by more than about that much.

**What causes it.** gsDesign's spending functions compute the spend as `1 - pnorm()`, which is exactly 0 once the true value is below about 1e-16: `sfLDOF(0.005, 0.1)$spend` is 0 where the exact spend is 6.9e-19. `gsBound1()` gives a zero spend the boundary 2.75e-89, so 986 of the 1024 rows of the first column are tied at that value. `.gsd_invert()` keeps the first of the tied rows, at the lowest level, 1e-14 (`R/transform_pvalues_gsd.R:365`), and interpolates from there to the first row with a positive spend.

**Code showing the problem** ([`reprex/C5.R`](reprex/C5.R)):

```r
# C5: first-analysis repeated p-values are wrong for raw p-values below about 1e-15
# Run: Rscript C5.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.1, 1)
p1 <- c(1e-25, 1e-20, 1e-17, 1e-12)        # first-analysis p-values; the final ones are 0.5
raw <- array(c(p1, rep(0.5, 4)), dim = c(4, 1, 2))
got <- transform_pvalues_gsd(raw, info_frac = info, spending = sfLDOF)$pvals[, 1, 1]

# At the first analysis the boundary is the spend itself, so the exact value has a closed form.
exact <- 2 * pnorm(qnorm(p1 / 2, lower.tail = FALSE) * sqrt(info[1]), lower.tail = FALSE)
print(signif(cbind(raw_p = p1, repeated_p = got, exact = exact, ratio = got / exact), 3))

cat("sfLDOF(0.005, 0.1)$spend:", sfLDOF(0.005, 0.1)$spend, " exact spend:",
    2 * pnorm(qnorm(0.0025, lower.tail = FALSE) / sqrt(0.1), lower.tail = FALSE), "\n")
cat("EXPECTED: ratio 1 in every row\n")
```

Output on `gsd-build`:

```
     raw_p repeated_p    exact ratio
[1,] 1e-25   0.000262 0.000913 0.286
[2,] 1e-20   0.001730 0.003150 0.547
[3,] 1e-17   0.005360 0.006700 0.799
[4,] 1e-12   0.024100 0.024100 1.000
sfLDOF(0.005, 0.1)$spend: 0  exact spend: 6.892266e-19
EXPECTED: ratio 1 in every row
```

**Potential fix.** The ST1 fix (patch 18, tested) already removes the anti-conservative direction: on the fixed build the script prints ratios of 9.7, 2.8 and 1.3. Exact values need a spending function that is accurate in the tail. Suggested: state the limit in the help and offer such a function, for example:

```r
# Lan-DeMets O'Brien-Fleming spending, accurate for very small spends
sf_ldof_tail <- function(alpha, t) {
    2 * stats::pnorm(
        stats::qnorm(alpha / 2, lower.tail = FALSE) / sqrt(pmin(t, 1)),
        lower.tail = FALSE
    )
}
```

Passed as `spending` in a trial run of the script's design, this function gave a ratio of 1 in every row on both builds. Adding it to the package has not been implemented or tested.

---

<a name="C6"></a>
## C6. An error inside a spending function or gsBound1() surfaces without the hypothesis it belongs to

- Functions: transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 23)

**What the error is.** When a function in the `spending` list fails, the user sees the raw error and nothing else. In the script the third of three functions is `gsDesign::sfHSD`, which needs a parameter the transform does not pass, and the whole message is `argument "param" is missing, with no default`: no hypothesis, no mention of `spending`. A function whose cumulative spend is negative or decreases fails later, inside gsDesign, with "probhi not on interval [0, 1)". A return value of the wrong length, by contrast, already gets a message that names the hypothesis.

**What causes it.** `.gsd_spend()` calls the function and coerces its value with no handler (`R/transform_pvalues_gsd.R:470-474`), and `.gsd_boundary_table()` calls `gsDesign::gsBound1()` the same way (lines 343-348). Both helpers receive `hyp` and use it only in their own messages.

**Code showing the problem** ([`reprex/C6.R`](reprex/C6.R)):

```r
# C6: an error inside a spending function surfaces without the hypothesis it belongs to
# Run: Rscript C6.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- array(runif(60), dim = c(10, 3, 2))       # 3 hypotheses, 2 analyses
spending <- list(sfLDOF, sfLDPocock, sfHSD)      # sfHSD needs a parameter, which is not given
msg <- tryCatch(
    {
        transform_pvalues_gsd(raw, info_frac = c(0.5, 1), spending = spending)
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("transform_pvalues_gsd() says:\n", msg, "\n")
cat("EXPECTED: an error that names hypothesis 3 and says that its spending function failed\n")
```

Output on `gsd-build`:

```
transform_pvalues_gsd() says:
 argument "param" is missing, with no default
EXPECTED: an error that names hypothesis 3 and says that its spending function failed
```

**Potential fix.** Run both calls under a calling handler that raises the error again with the hypothesis, the level and the information fractions, and keeps the original error as its parent. In `.gsd_spend()`:

```r
spent <- withCallingHandlers(
    {
        spent <- spending(alpha, t_look)
        if (is.list(spent) && !is.null(spent[["spend"]])) {
            spent <- spent[["spend"]]
        }
        as.numeric(spent)
    },
    error = function(cnd) {
        cli::cli_abort(
            c(
                "The spending function for hypothesis {hyp} is not usable.",
                x = "Calling it with a level of {alpha} at {length(t_look)} \\
                information fraction{?s} ({t_look}) gave an error."
            ),
            parent = cnd,
            call = call
        )
    }
)
```

With this change the script prints "The spending function for hypothesis 3 is not usable", the level and fraction it was called with, and the original error under "Caused by error". The `gsBound1()` call is wrapped the same way. Only the text of errors changes. A negative or decreasing spend is now caught before `gsBound1()`, by the check added for A5.

---

<a name="C7"></a>
## C7. The tolerance of a graph constraint is not carried into the optimiser

- Functions: graph_constraint(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 54)

**What the error is.** `graph_constraint(c(0.333, 0.333, 0.333), tolerance = 0.01)` is accepted, as the argument promises. The optimiser then cannot use the constraint. The default call stops with "Infeasible: no free weights and fixed sum=0.999000 (!=1)", which does not mention the tolerance the user set. With `global_search = FALSE` the local search runs first and the call then stops with "The supplied `hyp_weight` and `trans_matrix` do not build a valid graph", after two warnings.

**What causes it.** The tolerance is stored on the constraint (`R/graph_constraint.R:104, 150`) and used by the constructor. The optimisers work to `sqrt(.Machine$double.eps)`: the start-graph projection `closest_graph_to_constraints()` is called without the stored value (`R/optimisation_start.R:20`; its own default at `R/graph_constraint.R:436`), `is_graph_valid()` is called with its default after each stage (`R/optimisation.R:344, 464`), and the late error comes from the graph check of `calc_power_pvals()` (`R/calc_power.R:131-143`) inside the pruning step.

**Code showing the problem** ([`reprex/C7.R`](reprex/C7.R)):

```r
# C7: the tolerance of a graph constraint is not carried into the optimiser
# Run: Rscript C7.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")

# weights typed to three decimals, accepted because of the tolerance
con <- graph_constraint(c(0.333, 0.333, 0.333), tolerance = 0.01)
cat("constraint accepted: fixed weights sum to", sum(con$hyp_constraint),
    "with tolerance", attr(con, "tolerance"), "\n")

msg <- tryCatch(
    graph_optimise(P, con, gain, verbose = "silent"),
    error = function(e) conditionMessage(e)
)
cat("graph_optimise():", msg, "\n")
cat("EXPECTED: a search within the stored tolerance, or an error that names the tolerance\n")
```

Output on `gsd-build`:

```
constraint accepted: fixed weights sum to 0.999 with tolerance 0.01
graph_optimise(): Infeasible: no free weights and fixed sum=0.999000 (!=1).
EXPECTED: a search within the stored tolerance, or an error that names the tolerance
```

**Potential fix.** Make the two agree before any search: repeat the constructor's validation at the optimisers' tolerance and stop with a message that names both. Both optimisers call this right after the class check.

```r
check_graph_constraint_tolerance <- function(graph_constraint,
                                             arg = rlang::caller_arg(graph_constraint),
                                             call = rlang::caller_env()) {
    tolerance <- graph_constraint_get_tolerance(graph_constraint)
    optimiser_tolerance <- sqrt(.Machine$double.eps)
    if (tolerance <= optimiser_tolerance) {
        return(invisible(NULL))
    }
    strict_constraint <- graph_constraint
    attr(strict_constraint, "tolerance") <- optimiser_tolerance
    rlang::try_fetch(
        validate_graph_constraint(strict_constraint, call = call),
        error = function(cnd) {
            cli::cli_abort(
                "{.arg {arg}} was created with {.code tolerance = {tolerance}} and cannot be optimised as it is.",
                parent = cnd, call = call
            )
        }
    )
}
```

The tested message also gives the optimisers' tolerance and points to `normalise_sum()`. With this change the script stops at once, in both modes, with "`graph_constraint` was created with `tolerance = 0.01` and cannot be optimised as it is" and the rule that is broken. A constraint with a loose tolerance whose fixed values are exact is optimised as before. This fails early; it does not make the optimiser honour the tolerance. Carrying the tolerance through is the alternative, and would mean evaluating graphs whose weights do not sum to 1.

---

<a name="C8"></a>
## C8. A constraint of the wrong size is reported by base R or by the C++ kernel

- Functions: graph_constraint(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 55)

**What the error is.** Two size mistakes get messages that do not describe them. Four weights with a 3 x 3 matrix stop `graph_constraint()` with "length of 'dimnames' [1] not equal to array extent"; the package's own message for this case cannot be reached, and `diagnose = TRUE` prints nothing. A valid constraint for 3 hypotheses passed to `graph_optimise()` with p-values for 4 is reported by the kernel as "G must be an m x m matrix matching ncol(pvals)", in terms of an object the user never built.

**What causes it.** `graph_constraint()` builds the object before it validates it (`R/graph_constraint.R:145-153`), and `new_graph_constraint()` attaches the names as dimnames (`R/graph_constraint.R:19-22`), which is where base R stops. `assert_hc_tc_consistency()` (`R/graph_constraint_validation.R:94-113`) and the diagnosis run afterwards, so neither is reachable. The optimisers compare the gain with the p-values (`R/optimisation.R:146-151`) but never the constraint, so the mismatch travels to `src/graph_shortcut.cpp:70`.

**Code showing the problem** ([`reprex/C8.R`](reprex/C8.R)):

```r
# C8: a constraint of the wrong size is reported by base R or by the C++ kernel
# Run: Rscript C8.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 1. Four weights with a 3 x 3 matrix. The package has a message for this, and a diagnosis.
free3 <- rbind(c(0, NA, NA), c(NA, 0, NA), c(NA, NA, 0))
msg <- tryCatch(
    graph_constraint(c(NA, NA, NA, NA), free3, diagnose = TRUE),
    error = function(e) conditionMessage(e)
)
cat("graph_constraint(4 weights, 3 x 3 matrix):", msg, "\n")

# 2. A valid constraint for 3 hypotheses, p-values and gain for 4.
set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7, 0.6), nsim = 500)
gain <- trial_success(r1 + r2 + r3 + r4, verbose = "silent")
msg <- tryCatch(
    graph_optimise(P, graph_constraint_free(3), gain, verbose = "silent"),
    error = function(e) conditionMessage(e)
)
cat("graph_optimise(4 hypotheses, constraint for 3):", msg, "\n")
cat("EXPECTED: two errors from the package that name both sizes\n")
```

Output on `gsd-build`:

```
graph_constraint(4 weights, 3 x 3 matrix): length of 'dimnames' [1] not equal to array extent
graph_optimise(4 hypotheses, constraint for 3): G must be an m x m matrix matching ncol(pvals).
EXPECTED: two errors from the package that name both sizes
```

**Potential fix.** Compare the two sizes in `graph_constraint()` before the names are attached, using the existing assertion, and compare the constraint with the p-values at the top of both optimisers.

```r
# graph_constraint(), after `num_hyp <- length(hyp_constraint)`
if (any(dim(trans_constraint) != num_hyp)) {
    sizes <- list(hyp_constraint = hyp_constraint, trans_constraint = trans_constraint)
    if (diagnose) {
        diagnose_trans_constr_square(sizes)
        diagnose_hc_tc_consistency(sizes)
    }
    assert_hc_tc_consistency(sizes)
}

# graph_optimise(): check_graph_constraint_dims(graph_constraint, m = ncol(pvals))
m_constraint <- graph_constraint_get_m(graph_constraint)
if (m_constraint != m) {
    cli::cli_abort(
        "{.arg {arg}} is defined for {m_constraint} hypotheses, but {.arg pvals} holds {m}.",
        call = call
    )
}
```

With this change the first call prints the diagnosis and stops with "The transition matrix constraint has 3 rows and 3 columns while the hypothesis weight vector contains 4 elements"; the second stops with "`graph_constraint` is defined for 3 hypotheses, but `pvals` holds 4". Only the text of errors changes; valid input is untouched.

---

<a name="C9"></a>
## C9. Hypothesis names are not validated, and plot() fails after the optimisation

- Functions: graph_constraint(), graph_constraint_free(), graph_random(), plot()
- Branches: main and gsd-build
- Potential fix: tested (patches 56, 66)

**What the error is.** `graph_constraint()` accepts duplicated, empty and `NA` names. The optimisation runs to the end (gain 2.268 in the script), and `plot()` of the result then stops with igraph's "Duplicate vertex names", after the expensive step. Two smaller faces: `names = "auto"`, the documented default, is refused when passed explicitly ("`names` must have 3 elements. It has 1."), and names carried by the constraint vector, as in `c(PFS = NA, OS = NA, ORR = 0.2)`, are replaced by H1, H2, H3.

**What causes it.** Names are checked for type and length only (`R/graph_constraint.R:124, 139-143`), and they become the vertex names of the plot (`R/plot_graph_optimal.R:70-74`). The default is recognised with `missing(names)` (`R/graph_constraint.R:135`, also line 189 and `R/graph_random.R:71`), so the string "auto" itself is treated as one name. The constructor never reads the names of its inputs; `new_graph_constraint()` overwrites them (`R/graph_constraint.R:19-22`).

**Code showing the problem** ([`reprex/C9.R`](reprex/C9.R)):

```r
# C9: hypothesis names are not validated, and plot() fails after the optimisation
# Run: Rscript C9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 1000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
pdf(NULL)

# A name typed twice
msg <- tryCatch({
    con <- graph_constraint(c(NA, NA, NA), names = c("PFS", "PFS", "OS"))
    cat("graph_constraint(): accepted\n")
    res <- graph_optimise(P, con, gain, global_search = FALSE, verbose = "silent")
    cat("graph_optimise(): ran, gain", res$power$trial_success, "\n")
    suppressWarnings(plot(res))
    "no error"
}, error = function(e) conditionMessage(e))
cat("stopped with:", msg, "\n")

# The documented default, passed explicitly
msg <- tryCatch({
    con <- graph_constraint(c(NA, NA, NA), names = "auto")
    paste("accepted, names", paste(names(con$hyp_constraint), collapse = " "))
}, error = function(e) conditionMessage(e))
cat('names = "auto":', msg, "\n")
cat("EXPECTED: the repeated name refused by graph_constraint(); \"auto\" accepted as H1 H2 H3\n")
```

Output on `gsd-build`:

```
graph_constraint(): accepted
graph_optimise(): ran, gain 2.268
stopped with: Duplicate vertex names
names = "auto": `names` must have 3 elements. It has 1.
EXPECTED: the repeated name refused by graph_constraint(); "auto" accepted as H1 H2 H3
```

**Potential fix.** Resolve "auto" by value, prefer usable names carried by the inputs, and validate the result once in `graph_constraint()`.

```r
input_names <- if (rlang::is_named(hyp_constraint)) {
    names(hyp_constraint)
} else {
    rownames(trans_constraint)
}
# carried names that cannot serve as labels fall back to H1, H2, ...
if (!is.null(input_names) &&
    (anyNA(input_names) || !all(nzchar(input_names)) || anyDuplicated(input_names) > 0L)) {
    input_names <- NULL
}

if (identical(names, "auto")) {
    names <- input_names %||% build_hyp_names(num_hyp)
}

check_hyp_names(names)   # aborts on NA, "" or a repeated name
```

With this change the script stops in `graph_constraint()` with "`names` must be unique. Used more than once: "PFS"", and `names = "auto"` gives H1 H2 H3. A constraint built from a named vector or a matrix with row names now keeps those names. Patch 66 added the fall-back for bad carried names, since the first version aborted on input that had worked. `graph_random()` is not covered: on the fixed build it still refuses `names = "auto"` and still accepts a repeated name. The `identical()` test and a call to `check_hyp_names()` at `R/graph_random.R:71` would cure it (not tested).

---

<a name="C10"></a>
## C10. start_graph is checked for type and size only

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patches 51, 66)

**What the error is.** Three mistakes with `start_graph` get no useful response. One graph passed without the outer list, the natural first attempt, stops with "$ operator is invalid for atomic vectors". A start graph with weights `c(NA, 1, 1)` is accepted and the optimisation runs without a message; the same holds for `Inf`, negative weights, a non-zero diagonal and rows that sum to 2. A graph whose elements are misnamed (`w`, `G`) is treated as "no start graph" in silence.

**What causes it.** `.validate_start_graphs()` reads `hyp_weight` and `trans_matrix` with `$` from each element of whatever it is given (`R/optimisation_start.R:97-100`) and then checks type, length and dimensions only (lines 102-134). With an unwrapped graph the elements are the vector and the matrix themselves, so `$` fails. With misnamed elements both reads give `NULL`, every check passes with `allow_null = TRUE`, and `.build_start_matrix()` drops the graph (`R/optimisation_start.R:31-33`).

**Code showing the problem** ([`reprex/C10.R`](reprex/C10.R)):

```r
# C10: start_graph is checked for type and size only
# Run: Rscript C10.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
con <- graph_constraint_free(3)
ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
G <- matrix(0.5, 3, 3)
diag(G) <- 0

# 1. One valid graph, not wrapped in a list
msg <- tryCatch({
    graph_optimise(P, con, gain, control = ctrl, verbose = "silent",
                   start_graph = list(hyp_weight = c(0.5, 0.3, 0.2), trans_matrix = G))
    "accepted"
}, error = function(e) conditionMessage(e))
cat("one graph, not wrapped in a list:", msg, "\n")

# 2. Weights that are not weights: a missing value, and a sum of 2
msg <- tryCatch({
    graph_optimise(P, con, gain, control = ctrl, verbose = "silent",
                   start_graph = list(list(hyp_weight = c(NA, 1, 1), trans_matrix = G)))
    "accepted, and the optimisation ran without a message"
}, error = function(e) conditionMessage(e))
cat("weights NA 1 1:", msg, "\n")
cat("EXPECTED: 1 accepted (or an error that shows the list shape); 2 an error naming start_graph[[1]]$hyp_weight\n")
```

Output on `gsd-build`:

```
one graph, not wrapped in a list: $ operator is invalid for atomic vectors
weights NA 1 1: accepted, and the optimisation ran without a message
EXPECTED: 1 accepted (or an error that shows the list shape); 2 an error naming start_graph[[1]]$hyp_weight
```

**Potential fix.** Make `.validate_start_graphs()` return the start graphs in the documented shape, and check names and values there. Both optimisers use the returned value.

```r
# a single graph, not wrapped in a list
if (any(c("hyp_weight", "trans_matrix") %in% names(start_graph))) {
    start_graph <- list(start_graph)
}
tolerance <- 1e-2   # a start graph is projected before use; rounded input is fine

# inside the loop over graphs, after the existing type and size checks
other <- setdiff(rlang::names2(g), c("hyp_weight", "trans_matrix"))
if (is.null(w) && is.null(G) && length(other) > 0L) {
    cli::cli_abort("{.arg start_graph[[{i}]]} has no element named \\
        {.field hyp_weight} or {.field trans_matrix}.", call = call)
}
.validate_start_values(w, arg_name_w, tolerance, call = call)
.validate_start_values(G, arg_name_g, tolerance, call = call)
```

`.validate_start_values()` aborts on a value that is not finite or outside [0, 1], on weights or a row summing to more than 1, and on a non-zero diagonal. With this change the unwrapped graph in the script is accepted and the second call stops with "`start_graph[[1]]$hyp_weight` must not contain missing or infinite values". Sums below 1 are still accepted. The first version used a tolerance of `sqrt(.Machine$double.eps)` and refused graphs typed from printed output (weights summing to 1.0001); patch 66 set it to 0.01.

---

<a name="C11"></a>
## C11. Options of the local search are not checked, and a misspelt one is dropped in silence

- Functions: control_local(), graph_optimise(), graph_optimise_gsd(), print() of a result
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 52)

**What the error is.** `control_local(max_eval = 10)`, a slip for the nloptr option `maxeval`, raises nothing: the search uses 105 evaluations where the user believes the budget is 10. `maxeval = 0` (also -1 or `NA`) means "no limit" and likewise uses 105. Two related faces: an option nloptr refuses, such as a misspelt algorithm, stops the call only after the whole global search has run, and a local search that stopped at `maxeval` is still printed as "Optimal graph found".

**What causes it.** Nothing validates the option lists. `control_local()` stores whatever it is given (`R/control_local.R:22-27`), `control_prepare()` merges it over the defaults (`R/control_prepare.R:102-105`), and the list first meets `nloptr::nloptr()` at `R/optimisation.R:449-455`, after the global stage at lines 167-178. nloptr ignores a name it does not know and reads a `maxeval` below 1 as "criterion disabled". `print()` writes its heading without looking at nloptr's status (`R/graph_optimal.R:193-196`).

**Code showing the problem** ([`reprex/C11.R`](reprex/C11.R)):

```r
# C11: options of the local search are not checked; a misspelt one is dropped in silence
# Run: Rscript C11.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
con <- graph_constraint_free(3)

# 1. `max_eval` typed for the nloptr option `maxeval`: the user believes the budget is 10
ctrl <- control_local(multigrain_control(), max_eval = 10)
msg <- tryCatch({
    res <- graph_optimise(P, con, gain, global_search = FALSE, control = ctrl, verbose = "silent")
    paste("no error, no warning; evaluations used:", res$local_output$iterations)
}, error = function(e) conditionMessage(e))
cat("control_local(max_eval = 10):", msg, "\n")

# 2. a budget of 0 evaluations
ctrl <- control_local(multigrain_control(), maxeval = 0)
msg <- tryCatch({
    res <- graph_optimise(P, con, gain, global_search = FALSE, control = ctrl, verbose = "silent")
    paste("no error, no warning; evaluations used:", res$local_output$iterations)
}, error = function(e) conditionMessage(e))
cat("control_local(maxeval = 0):", msg, "\n")
cat("EXPECTED: an error for the unknown name `max_eval`, and for a `maxeval` below 1\n")
```

Output on `gsd-build`:

```
control_local(max_eval = 10): no error, no warning; evaluations used: 105
control_local(maxeval = 0): no error, no warning; evaluations used: 105
EXPECTED: an error for the unknown name `max_eval`, and for a `maxeval` below 1
```

**Potential fix.** Check the merged options at the end of `control_prepare()` and `control_prepare_dims()`, which both optimisers call before the first stage.

```r
check_control_opts <- function(ctrl, call = rlang::caller_env()) {
    local_opt <- ctrl$local_opt
    known_local <- c(nloptr::nloptr.get.default.options()$name, "local_opts")
    unknown_local <- setdiff(names(local_opt), known_local)
    if (length(unknown_local) > 0L) {
        cli::cli_abort("Unknown local optimisation option{?s} in \\
            {.arg control}: {.val {unknown_local}}.", call = call)
    }
    maxeval <- local_opt$maxeval
    if (!rlang::is_scalar_integerish(maxeval, finite = TRUE) || maxeval < 1) {
        cli::cli_abort("The local optimisation option {.field maxeval} must \\
            be a whole number of at least 1.", call = call)
    }
    # whatever else nloptr refuses is refused now, on a one-evaluation dummy problem
    trial_opt <- local_opt
    trial_opt$maxeval <- 1
    nloptr::nloptr(x0 = c(0.5, 0.5), eval_f = function(x) 0,
                   lb = c(0, 0), ub = c(1, 1), opts = trial_opt)
    invisible(ctrl)
}
```

The tested version also checks the names set with `control_global()` against the arguments of `GA::ga()`, silences the trial call and wraps nloptr's own error. With this change both calls in the script stop before any search, the first with "Unknown local optimisation option in `control`: "max_eval"", and `print()` leads with "Graph found when the local search stopped at its evaluation limit" when nloptr's status is 5. Refusing a `maxeval` below 1 removes nloptr's way of running without a limit; a warning is the alternative. Four of the package's own tests passed `max_eval`.

---

<a name="C12"></a>
## C12. control_global() can replace the objective, the bounds and the start graphs of the global search

- Functions: control_global(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 53)

**What the error is.** `control_global()` passes any `GA::ga()` argument through, including the four the optimiser must own. In the script `control_global(fitness = function(x) 42)` is accepted and the global search reports a best value of 42 for a gain that cannot exceed 3: the genetic algorithm maximised the user's function, not the trial success measure. In the same way `lower` and `upper` move the search outside [0, 1], and `suggestions` replaces the default seeds and the user's own `start_graph`. No message is given in any of these cases.

**What causes it.** `.graph_optimise_ga()` builds these arguments in a list called `immutable_global_args` and then merges the user's options over it with `utils::modifyList(immutable_global_args, global_opts)` (`R/optimisation.R:316-338`; the same at `R/optimisation_gsd.R:398-421`). In `modifyList()` the second list wins, so the list is not immutable.

**Code showing the problem** ([`reprex/C12.R`](reprex/C12.R)):

```r
# C12: control_global() can replace the objective the optimiser maximises
# Run: Rscript C12.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")   # cannot exceed 3

ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
ctrl <- control_global(ctrl, fitness = function(x) 42)     # a GA::ga() argument

msg <- tryCatch({
    set.seed(2)
    res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")
    paste("accepted; best value found by the global search:", res$global_output@fitnessValue)
}, error = function(e) conditionMessage(e))
cat("control_global(fitness = function(x) 42):", msg, "\n")
cat("EXPECTED: an error, since the objective is not a user option\n")
```

Output on `gsd-build`:

```
control_global(fitness = function(x) 42): accepted; best value found by the global search: 42
EXPECTED: an error, since the objective is not a user option
```

**Potential fix.** Refuse the four names before any optimisation starts, in the option check that `control_prepare()` and `control_prepare_dims()` run (see C11). The merge itself is left as it is.

```r
reserved_global <- intersect(
    names(global_opt),
    c("fitness", "lower", "upper", "suggestions")
)
if (length(reserved_global) > 0L) {
    cli::cli_abort(
        c(
            "{.fn control_global} cannot set the {.fn GA::ga} \\
            argument{?s} {.val {reserved_global}}.",
            i = "The optimiser sets them: {.field fitness} is the trial \\
            success measure, {.field lower} and {.field upper} are 0 and 1 \\
            for every parameter, and {.field suggestions} are the default \\
            start graphs and those in {.arg start_graph}."
        ),
        call = call
    )
}
```

With this change the script stops with "`control_global()` cannot set the `GA::ga()` argument "fitness"". Nothing changes for other options. The same list also holds `type`, `population`, `mutation` and `optim`; they are left open, since `optim = FALSE` or a custom mutation are plausible expert settings. Swapping the two arguments of `modifyList()` is the alternative: it would ignore the user's value in silence, where this fix reports it.

---

<a name="C13"></a>
## C13. A flat sum of a few hundred terms cannot be turned into a gain: the C stack runs out

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: suggested, not implemented

**What the error is.** A gain written as one long sum, such as a utility table with a term for each of the 512 rejection patterns of 9 hypotheses, stops with R's "C stack usage ... is too close to the limit". With the 8 MB stack of this Linux machine the translator of `trial_success()` handled 380 terms and failed at 400; that of `trial_success_gsd()` handled 250 and failed at 270. The message says nothing about the expression. The same 600 terms in parentheses, 20 to a group, build and give the right value (300).

**What causes it.** R parses `a + b + c + ...` into a tree nested once per term. The validators and the translators walk that tree by calling themselves through `lapply()`: `validate_expr_symbols()` (`R/trial_success.R:251`), `parse_and_transform()` (`:499`), `validate_expr_symbols_gsd()` (`R/trial_success_gsd.R:592-596`) and `.gsd_gain_transform_call()` (`:887-891`). Each term costs several nested R calls, and these exhaust the C stack. `deparse1()` and `str2lang()` handled 1,000 terms.

**Code showing the problem** ([`reprex/C13.R`](reprex/C13.R)):

```r
# C13: a long flat sum cannot be turned into a gain: the C stack runs out
# Run: Rscript C13.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 600 terms, as in a utility table with one term per rejection pattern
terms <- sprintf("0.5 * r%d", rep(1:3, length.out = 600))

flat <- paste(terms, collapse = " + ")
msg <- tryCatch({ trial_success(!!flat, verbose = "silent"); "built" },
                error = function(e) conditionMessage(e))
cat("600 terms as one flat sum      :", msg, "\n")

# The same terms, 20 to a pair of parentheses
groups <- tapply(terms, rep(1:30, each = 20), paste, collapse = " + ")
grouped <- paste0("(", groups, ")", collapse = " + ")
g <- trial_success(!!grouped, verbose = "silent")
cat("600 terms in 30 groups of 20   : built; value with every hypothesis rejected",
    g$func(matrix(TRUE, 1, 3)), " (correct: 300)\n")
cat("EXPECTED: the flat sum is built too, or the error says to group the terms\n")
```

Output on `gsd-build`:

```
600 terms as one flat sum      : C stack usage  7974340 is too close to the limit
600 terms in 30 groups of 20   : built; value with every hypothesis rejected 300  (correct: 300)
EXPECTED: the flat sum is built too, or the error says to group the terms
```

**Potential fix.** Read a chain of `+` and `-` along its left spine in a loop, and give each term to the existing walkers on its own. A helper for both families:

```r
# The terms of `a + b - c + ...` and their signs, without recursion
.gain_sum_terms <- function(ast) {
    terms <- list()
    signs <- character()
    while (is.call(ast) && length(ast) == 3L &&
           as.character(ast[[1L]]) %in% c("+", "-")) {
        terms <- c(list(ast[[3L]]), terms)
        signs <- c(as.character(ast[[1L]]), signs)
        ast <- ast[[2L]]
    }
    list(terms = c(list(ast), terms), signs = c("+", signs))
}

# replace_r_indices(): one piece of C++ per term
parts <- .gain_sum_terms(ast)
cpp <- vapply(parts$terms, function(term) {
    validate_expr_symbols(term, logic_ops = c("%AND%", "%OR%"))
    deparse1(parse_and_transform(term)$expr)
}, character(1))
out_str <- paste0(parts$signs, " (", cpp, ")", collapse = " ")
```

This is not in the fix branch and has not been run through the test suite. A prototype outside the package, using the walkers of the fixed build, built a 2,000-term sum that equalled plain R on all 8 patterns of 3 hypotheses. The `logic_ops` argument exists on the fixed build only (patch 32); on `gsd-build`, where `replace_r_indices()` does not validate, that line is left out. `resolve_expr()` and the group sequential twins need the same loop. The cheap alternative is to catch the stack error and say that the terms should be grouped in parentheses.

---

<a name="C14"></a>
## C14. trial_success_gsd() cannot compile a sign applied to a signed value

- Functions: trial_success_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 37)

**What the error is.** `trial_success_gsd()` accepts unary minus, but a minus applied to a negative value fails in the C++ compiler. With `penalty <- -0.5`, the gain `r1 + (-!!penalty) * r2` stops with "Error 1 occurred building shared library" after raw compiler output whose first error is "lvalue required as decrement operand". The same happens for `-(-r1)`. A user who holds a cost as a negative number and subtracts it meets this, and the message does not point at the expression.

**What causes it.** `.gsd_gain_transform_call()` removes parentheses from the tree (`R/trial_success_gsd.R:844-846`) and rebuilds a unary call around its transformed operand (`:892-899`). The C++ text is then produced by `deparse1()` (`:802`), which writes a minus applied to a minus, or to a negative constant, as `--0.5`. C++ reads `--` as the decrement operator. `deparse()` only puts back the parentheses that R's own precedence needs, and R needs none here.

**Code showing the problem** ([`reprex/C14.R`](reprex/C14.R)):

```r
# C14: trial_success_gsd() cannot compile a minus sign applied to a negative value
# Run: Rscript C14.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

penalty <- -0.5     # held as a negative number; the gain subtracts it
log <- capture.output(
    g <- tryCatch(trial_success_gsd(r1 + (-!!penalty) * r2, K = 2, verbose = "silent"),
                  error = function(e) conditionMessage(e))
)
if (is.character(g)) {
    cat("trial_success_gsd(r1 + (-!!penalty) * r2):", g, "\n")
    cpp <- grep("total \\+=", log, value = TRUE)[1]
    cat("generated C++:", sub(";.*", "", sub(".*total", "total", cpp)), "\n")
    cat("compiler:", sub(".*error: ", "error: ", grep("error:", log, value = TRUE)[1]), "\n")
} else {
    cat("built; value when both are rejected:", g$func(matrix(1L, 1, 2)), "\n")
}
cat("EXPECTED: built, with value 1.5 when both hypotheses are rejected\n")
```

Output on `gsd-build`:

```
trial_success_gsd(r1 + (-!!penalty) * r2): Error 1 occurred building shared library.
generated C++: total += (double(t(i, 0) > 0) + --0.5 * double(t(i, 1) > 0))
compiler: error: lvalue required as decrement operand
EXPECTED: built, with value 1.5 when both hypotheses are rejected
```

**Potential fix.** Keep the parentheses when the operand of a unary sign itself begins with a sign. In `R/trial_success_gsd.R`:

```r
.gsd_gain_leads_with_sign <- function(expr) {
    if (is.call(expr)) {
        length(expr) == 2L && as.character(expr[[1L]]) %in% c("-", "+")
    } else {
        grepl("^[-+]", as.character(expr))
    }
}

# .gsd_gain_transform_call(), unary branch
if (length(transformed_args) == 1L) {
    operand <- transformed_args[[1L]]$expr
    if (.gsd_gain_leads_with_sign(operand)) {
        new_call <- call(op_text, call("(", operand))
    }
    return(list(expr = new_call, type = "real"))
}
```

With this change the script builds the gain and prints 1.5 when both hypotheses are rejected; the generated text is `-(-0.5)`. An expression with a single sign is written exactly as before. The fix of C16 reuses the helper for `trial_success()`.

---

<a name="C15"></a>
## C15. trial_success() fails in the C++ compiler on a value taken from a named vector

- Functions: trial_success()
- Branches: main and gsd-build
- Potential fix: tested (patches 29, 39)

**What the error is.** With `w <- c(pfs = 0.4, os = 0.6)`, the gain `trial_success(!!w["pfs"] * r1 + !!w["os"] * r2)` passes the package's checks and then stops with "Error 1 occurred building shared library" after 15 lines of compiler output. Weights kept in a named vector are a natural way to write a gain, and `trial_success_gsd()` accepts the same expression. Two neighbours: a constant of length 2 (`!!c(1, 2) * r1`) fails in the compiler too, and a call without `objective` blames a symbol with an empty name.

**What causes it.** `validate_expr_symbols()` accepts any numeric value (`R/trial_success.R:266`), of any length, named or not. `resolve_expr()` then deparses the expression to a string (`:208`), and `deparse1()` writes a named value as `c(pfs = 0.4)`. `replace_r_indices()` parses that string again (`:381`), and `parse_and_transform()` copies the call to `c()` into the C++ text as "some other function" (`:515-518`). `trial_success_gsd()` compiles from the captured expression, not from its text (`R/trial_success_gsd.R:202`), so it never sees the name.

**Code showing the problem** ([`reprex/C15.R`](reprex/C15.R)):

```r
# C15: trial_success() fails in the C++ compiler on a value taken from a named vector
# Run: Rscript C15.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(pfs = 0.4, os = 0.6)
log <- capture.output(
    g <- tryCatch(trial_success(!!w["pfs"] * r1 + !!w["os"] * r2, verbose = "silent"),
                  error = function(e) conditionMessage(e))
)
if (is.character(g)) {
    cat("trial_success(!!w[\"pfs\"] * r1 + !!w[\"os\"] * r2):", g, "\n")
    cpp <- grep("total \\+=", log, value = TRUE)[1]
    cat("generated C++:", sub(";.*", "", sub(".*total", "total", cpp)), "\n")
    cat("lines of compiler output printed to the console:", length(log), "\n")
} else {
    cat("built; value when both are rejected:", g$func(matrix(TRUE, 1, 2)), "\n")
}
cat("EXPECTED: built, with value 1 when both hypotheses are rejected\n")
```

Output on `gsd-build`:

```
trial_success(!!w["pfs"] * r1 + !!w["os"] * r2): Error 1 occurred building shared library.
generated C++: total += (c(pfs = 0.4) * double(x(i, 0)) + c(os = 0.6) * double(x(i, 1)))
lines of compiler output printed to the console: 15
EXPECTED: built, with value 1 when both hypotheses are rejected
```

**Potential fix.** Compile expression input from the captured expression, with each constant replaced by its exact text first; keep the deparsed string for display only. In `R/trial_success.R`:

```r
deparse_expr_exact <- function(expr_lang) {
    constants_as_text <- function(node) {
        if (is.call(node)) {
            as.call(lapply(as.list(node), constants_as_text))
        } else if (is.numeric(node)) {
            as.symbol(.gsd_gain_cpp_number(node))
        } else {
            node
        }
    }
    out_str <- deparse1(constants_as_text(expr_lang), width.cutoff = 500)
    gsub("`", "", out_str, fixed = TRUE)
}

# new_trial_success()
cpp_body <- replace_r_indices(
    if (is.null(expr_lang)) expr_string else deparse_expr_exact(expr_lang)
)
```

With this change the script builds the gain and prints 1. A constant that is a vector is refused by the validator, and both constructors call `rlang::check_required(objective)`: "`objective` is absent but must be supplied". One side effect for valid input, shared with ENV01: an injected constant that 15 digits cannot hold is now compiled exactly.

---

<a name="C16"></a>
## C16. trial_success() cannot build a gain with a constant that R prints in exponent form (100000, 0.0001) or with a negative constant

- Functions: trial_success()
- Branches: main and gsd-build
- Potential fix: tested (patches 28, 38)

**What the error is.** Two limitations noted in `dev/gsd_design_record.md` reach further than recorded there. `trial_success(100000 * r1 + r2)` stops with "Error 1 occurred building shared library" after raw compiler output: any constant that R prints in exponent form is affected, which includes 100000 and 0.0001 as well as `1e-05`. Every negative constant fails too, typed or injected: with `penalty <- -0.5`, `trial_success(r1 + !!penalty * r2)` stops with "subscript out of bounds". The workaround in the help, `0 - r1`, does not cover an injected value. A gain written as value minus cost meets the second at once.

**What causes it.** Constants are written with `as.character()`, and `.0` is appended when the text has no point (`R/trial_success.R:543-546`): 100000 becomes `1e+05.0`, which is not a C++ number. For the sign, `parse_and_transform()` reads a second operand from every arithmetic call (`:508-509`), and a unary minus has one. A negative value injected with `!!` turns into a unary minus on the way: the expression is deparsed to a string (`:208`) and parsed again (`:381`).

**Code showing the problem** ([`reprex/C16.R`](reprex/C16.R)):

```r
# C16: trial_success() cannot build a gain with a constant that R prints in exponent form, or a negative one
# Run: Rscript C16.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 1. A constant that R prints in exponent form (100000 or 0.0001, for example; 123456 builds)
log <- capture.output(
    big <- tryCatch({ trial_success(100000 * r1 + r2, verbose = "silent"); "built" },
                    error = function(e) conditionMessage(e))
)
cat("trial_success(100000 * r1 + r2):", big, "\n")
cpp <- grep("total \\+=", log, value = TRUE)
if (length(cpp) > 0) cat("  generated C++:", sub(";.*", "", sub(".*total", "total", cpp[1])), "\n")

# 2. A negative constant, typed or injected
penalty <- -0.5
neg <- tryCatch({ trial_success(r1 + !!penalty * r2, verbose = "silent"); "built" },
                error = function(e) conditionMessage(e))
cat("trial_success(r1 + !!penalty * r2), penalty = -0.5:", neg, "\n")
cat("EXPECTED: both gains are built\n")
```

Output on `gsd-build`:

```
trial_success(100000 * r1 + r2): Error 1 occurred building shared library.
  generated C++: total += (1e+05.0 * double(x(i, 0)) + double(x(i, 1)))
trial_success(r1 + !!penalty * r2), penalty = -0.5: subscript out of bounds
EXPECTED: both gains are built
```

**Potential fix.** Write constants with the session-independent formatter shown under ENV01, and translate a unary sign as `trial_success_gsd()` does. In `parse_and_transform()` (`R/trial_success.R`):

```r
if (op_text %in% c("+", "-", "*", "/")) {
    if (length(transformed_args) == 1L) {
        # Unary minus or plus => real. An operand that itself begins
        # with a sign keeps its parentheses (see C14)
        operand <- transformed_args[[1]]$expr
        if (.gsd_gain_leads_with_sign(operand)) {
            new_call <- call(op_text, call("(", operand))
        }
        return(list(expr = new_call, type = "real"))
    }
    left_type <- transformed_args[[1]]$type
    right_type <- transformed_args[[2]]$type
    # ... as before ...
}
```

With this change the script reports "built" for both gains. Every expression affected was an error before, so no existing gain changes its value. The "Known limitations" note in the help (`R/trial_success.R:97-100`) no longer needs its unary minus item.

---

<a name="C17"></a>
## C17. A mistyped hypothesis index is accepted, however large

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: tested (patch 41)

**What the error is.** The index of `r<i>` or `t<i>` has no upper limit. `trial_success(r100001 + r2)` is accepted: after some seconds (5.6 in the run shown, more on a busy machine) the constructor gives a warning of 688,975 characters that lists every missing index, and it would then go on to compile a gain over 100,001 hypotheses. With one digit more, `r1000001`, it had said nothing after 60 seconds. A slip of the keyboard should be an immediate error.

**What causes it.** `count_unique_indices()` takes the largest index as the number of hypotheses, builds `1:max_index_found` (`R/trial_success.R:413-414`) and puts every missing index into the warning with `toString(missing_indices)` (`:425-429`). `count_unique_indices_gsd()` does the same (`R/trial_success_gsd.R:757-765`). Neither compares the index with anything.

**Code showing the problem** ([`reprex/C17.R`](reprex/C17.R)):

```r
# C17: a mistyped hypothesis index is accepted, however large
# Run: Rscript C17.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# r100001 for r1 (a slip of the keyboard). Only the gap warning is caught here,
# so nothing is compiled.
start <- Sys.time()
warned <- tryCatch(trial_success(r100001 + r2, verbose = "silent"),
                   warning = function(w) conditionMessage(w))
cat("seconds until the constructor says anything:",
    round(as.numeric(Sys.time() - start, units = "secs"), 1), "\n")
cat("it is a warning of", nchar(warned), "characters, beginning:\n ", substr(warned, 1, 90), "\n")
cat("EXPECTED: an immediate error for an index no design can have\n")
```

Output on `gsd-build`:

```
seconds until the constructor says anything: 5.6
it is a warning of 688975 characters, beginning:
  Missing indices in the sequence. Expected every index from 1 to 100001, but
missing 1, 3,
EXPECTED: an immediate error for an index no design can have
```

**Potential fix.** Refuse an index above a fixed limit before the gap check. In `count_unique_indices()` (`R/trial_success.R`), and the same in `count_unique_indices_gsd()`:

```r
trial_success_max_index <- 1000L

# Compared as doubles: an index beyond the integer range is NA after
# as.integer()
above_max <- unique(
    all_matches[as.numeric(indices) > trial_success_max_index]
)
if (length(above_max) > 0L) {
    cli::cli_abort(
        c(
            "A trial success expression can refer to at most \\
            {trial_success_max_index} hypotheses.",
            x = "{.code {above_max}} {?is/are} above that limit."
        )
    )
}
```

With this change the script stops at once: "A trial success expression can refer to at most 1000 hypotheses. `r100001` is above that limit." The limit is a judgement call, since a gain that really uses an index above 1000 is now refused; the alternative, or an addition, is a gap warning that summarises ("missing 1 and 3 to 100000") in place of listing every index.

---

<a name="C18"></a>
## C18. A discount table that the gain never applies is accepted without a word

- Functions: trial_success_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 42)

**What the error is.** `trial_success_gsd(r1 + r2, d = c(1, 0.8))` builds without a message. The object prints "Discount table d(t): 1.0, 0.8" and "Analyses (K): 2", so it looks discounted, yet the gain is 2 whether both hypotheses are rejected at analysis 1 or at analysis 2, where 1.6 was meant. A design optimised with it puts no value on early rejection. The same gap hides a typing slip: `k = 3` written for `K = 3` is taken as a one-value table called `k`, `K` becomes 1, and the only warning is that the table has a value outside [0, 1].

**What causes it.** `.gsd_gain_tables()` validates the tables passed through `...` on their own (`R/trial_success_gsd.R:267-342`), and `.gsd_gain_K()` takes `K` from their length (`:434-443`). The expression is checked for table names it uses (`:547-565`), but nothing checks that each table supplied is used. Any named argument other than `K` and `verbose` is a table (`:192`).

**Code showing the problem** ([`reprex/C18.R`](reprex/C18.R)):

```r
# C18: a discount table that the gain never applies is accepted without a word
# Run: Rscript C18.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Meant: a rejection at the second analysis is worth 80% of one at the first.
# Written with r1, r2 where d(t1), d(t2) were needed.
g <- trial_success_gsd(r1 + r2, d = c(1, 0.8), verbose = "silent")
print(g)

early <- matrix(1L, 1, 2)    # both hypotheses rejected at analysis 1
late  <- matrix(2L, 1, 2)    # both rejected at analysis 2
cat("gain, both rejected at analysis 1:", g$func(early), "\n")
cat("gain, both rejected at analysis 2:", g$func(late), " (1.6 if the table were applied)\n")
cat("EXPECTED: a warning that discount table `d` is not used in the objective\n")
```

Output on `gsd-build`:

```
<multigrain_trial_success_gsd/multigrain_trial_success>
r1 + r2
Analyses (K): 2
Discount table d(t): 1.0, 0.8
gain, both rejected at analysis 1: 2
gain, both rejected at analysis 2: 2  (1.6 if the table were applied)
EXPECTED: a warning that discount table `d` is not used in the objective
```

**Potential fix.** Compare the table names with the parsed expression and warn about any that is never applied. In `replace_indices_gsd()` (`R/trial_success_gsd.R`), after validation:

```r
# After validation a table name can only occur as the head of a call,
# so all.names() finds every use.
unused <- setdiff(table_names, all.names(ast))
if (length(unused) > 0L) {
    cli::cli_warn(
        c(
            "Discount table{?s} {.arg {unused}} {?is/are} not used in \\
            {.arg objective} and {?has/have} no effect on the gain.",
            i = "Apply a table to a decision time, e.g. \\
            {.code {unused[[1L]]}(t1)}, or leave it out; the number of \\
            analyses can be given as {.arg K}."
        )
    )
}
```

With this change the script prints the same object and values, preceded by the warning "Discount table `d` is not used in `objective` and has no effect on the gain". Nothing changes for a gain that applies its tables. Warning or error is a judgement call: a warning leaves room for a user who passes a table only to set `K`.

---

<a name="C19"></a>
## C19. Every gain keeps a shared library loaded and build files on disk until the session ends

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: suggested, not implemented

**What the error is.** Each gain with a different expression or different injected values is compiled into its own shared library (round 1 C19, measured in round 2 as MEM5). After two gains were built, removed and garbage-collected, both libraries were still loaded and `tempdir()` held 12 more files, 3.7 MB. R limits the number of loaded libraries, to 614 at most by default. A sweep over a few hundred weights therefore ends with "maximal number of DLLs reached", seen here with the limit lowered to 100, and nothing in the help says so.

**What causes it.** `sourceCpp()` (`R/trial_success.R:314`, `R/trial_success_gsd.R:713`) builds and loads one library per distinct C++ source. A value injected with `!!` is written into that source as a literal, so every scenario of a sweep is a new source. Nothing unloads the library or removes its build directory when the gain object is collected. The cost per gain is one loaded library and about 2 MB of disk.

**Code showing the problem** ([`reprex/C19.R`](reprex/C19.R)):

```r
# C19: every gain keeps a shared library loaded and files on disk until the session ends
# Run: Rscript C19.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

loaded <- function() sum(grepl("^sourceCpp", names(getLoadedDLLs())))
on_disk <- function() {
    files <- list.files(tempdir(), recursive = TRUE, full.names = TRUE)
    c(files = length(files), MB = round(sum(file.size(files)) / 1e6, 1))
}
dll_before <- loaded()
disk_before <- on_disk()

# Two scenarios of a sweep over a weight; each gain is dropped after use
for (w in c(0.4, 0.6)) {
    g <- trial_success(!!w * r1 + r2, verbose = "silent")
    rm(g)
}
invisible(gc())

cat("gain libraries loaded, before and after 2 gains were built and discarded:",
    dll_before, loaded(), "\n")
cat("left in tempdir():", on_disk()[["files"]] - disk_before[["files"]], "files,",
    on_disk()[["MB"]] - disk_before[["MB"]], "MB\n")
cat("limit on loaded libraries (R_MAX_NUM_DLLS):",
    Sys.getenv("R_MAX_NUM_DLLS", "not set, so R's default of 614 at most"), "\n")
cat("EXPECTED: the library of a discarded gain is released, or the help states the limit\n")
```

Output on `gsd-build`:

```
gain libraries loaded, before and after 2 gains were built and discarded: 0 2
left in tempdir(): 12 files, 3.7 MB
limit on loaded libraries (R_MAX_NUM_DLLS): not set, so R's default of 614 at most
EXPECTED: the library of a discarded gain is released, or the help states the limit
```

**Potential fix.** Not fixed in the fix branch. The smallest step is to state the limit where users will look, in the details of both constructors:

```r
#' ## One compiled library per gain
#'
#' Every gain with a different expression, or with different injected
#' values, is compiled into its own shared library. The library stays
#' loaded, and about 2 MB of build files stay in `tempdir()`, until the R
#' session ends. R limits the number of loaded libraries (see
#' `R_MAX_NUM_DLLS` in [dyn.load()]), so one session can build a few
#' hundred distinct gains. Run a larger sweep in batches, each in a fresh
#' R process.
```

This text is a suggestion and has not been tested or added. The real cure is a design change: pass the constants to the compiled function as arguments, so that a sweep over weights compiles one library. Unloading the library when the gain is collected is not safe as the code stands: two gains built from the same expression share one library (checked: the second build loads nothing and both objects call the same entry point), so collecting one would break the other.

---

<a name="C20"></a>
## C20. A custom_power entry named like a built-in output field is hidden behind it

- Functions: calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 13)

**What the error is.** A user who names an own measure `disj_power` gets a result with two elements of that name. `out$disj_power` returns the package's value (0.9685 in the script: any of the three hypotheses), and the user's value (0.949: H1 or H2) can be reached only as `out[[5]]`. There is no message. The same holds for the other three built-in names, and for all seven of `calc_power_pvals_gsd()`. A second defect sits in the same place: an element of the wrong type is always described as "a string", so `custom_power = list(a = 3)` gives "must be a function or a <multigrain_trial_success> object, not a string".

**What causes it.** `.auto_name_custom_power()` checks the type of each entry and fills in missing names (`R/calc_power.R:229-236`). It never compares the names with the four fields that `calc_power_pvals()` builds, and the two lists are joined with `c()` (`R/calc_power.R:155-163`). `.auto_name_custom_power_gsd()` is the same (`R/calc_power_gsd.R:282-289`). The type message contains `{.obj_type_friendly item}` (`R/calc_power.R:224`, `R/calc_power_gsd.R:277`): without inner braces cli formats the text "item", which is a string.

**Code showing the problem** ([`reprex/C20.R`](reprex/C20.R)):

```r
# C20: a custom_power entry named like a built-in output field is hidden behind it
# Run: Rscript C20.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 2000)
w <- rep(1, 3) / 3
G <- (1 - diag(3)) / 2

# the user's own "disjunctive power": H1 or H2, leaving H3 out
out <- calc_power_pvals(pvals, w, G,
                        custom_power = list(disj_power = function(x) x[1] || x[2]))
cat("names of the result:", names(out), "\n")
cat("out$disj_power:", out$disj_power, " (the built-in value: any of the three)\n")
cat("out[[5]]:      ", out[[5]], " (the user's value, reachable by position only)\n")

# second face: an element of the wrong type is always described as "a string"
msg <- tryCatch(calc_power_pvals(pvals, w, G, custom_power = list(a = 3)),
                error = function(e) conditionMessage(e))
cat("custom_power = list(a = 3):", gsub("\\s+", " ", msg), "\n")
cat("EXPECTED: an error for the name `disj_power`, and \"not a number\" in the last message\n")
```

Output on `gsd-build`:

```
names of the result: local_power exp_rejections disj_power conj_power disj_power
out$disj_power: 0.9685  (the built-in value: any of the three)
out[[5]]:       0.949  (the user's value, reachable by position only)
custom_power = list(a = 3): Each element of `custom_power` must be a function or a <multigrain_trial_success> object, not a string.
EXPECTED: an error for the name `disj_power`, and "not a number" in the last message
```

**Potential fix.** Refuse the reserved names where the names are settled, and add the missing braces:

```r
.check_custom_power_names <- function(nms, reserved, call = rlang::caller_env()) {
    clash <- intersect(nms, reserved)
    if (length(clash) > 0L) {
        cli::cli_abort(
            c(
                "{.arg custom_power} must not use the name{?s} {.val {clash}}.",
                x = "The built-in output fields are named {.val {reserved}}; \\
                {.code $} would return those, not the custom measure."
            ),
            call = call
        )
    }
    invisible(NULL)
}
```

It is called at the end of both `.auto_name_custom_power*()` functions with their own field names, and the two messages become `not {.obj_type_friendly {item}}`. With this change the script stops with "`custom_power` must not use the name "disj_power"", and `list(a = 3)` is reported as "not a number". The only input refused that was accepted before is an entry with one of these names. Two user entries that share a name are still accepted.

---

<a name="C21"></a>
## C21. calc_power_pvals_gsd() refuses a gain that does not mention the last hypothesis

- Functions: calc_power_pvals_gsd()
- Branches: gsd-build only
- Potential fix: suggested, not implemented

**What the error is.** On a design with two hypotheses, "the probability that H1 is rejected at the interim" is the gain `(t1 == 1) + 0`. `calc_power_pvals_gsd()` refuses it: "`custom_power$g` and `pvals` disagree on the number of hypotheses". Padding the gain with `+ 0 * r2` gives 0.15, the value in `local_power_by_analysis`. The fixed-sample gain `r1 + 0` is refused in the same way, although `calc_power_pvals()` accepts it and the help says that such a gain "reports the same number here as `calc_power_pvals()` would". A measure on a subset of the hypotheses is an ordinary thing to ask for.

**What causes it.** A gain's `m` is the largest index it mentions (`R/trial_success_gsd.R:649`). `.gsd_check_gain_dims()` stops whenever `trial_success$m != pvals$m` (`R/check_gsd.R:82`), and `calc_power_pvals_gsd()` applies it to every compiled entry of `custom_power` (`R/calc_power_gsd.R:135-144`). Only a gain over more hypotheses than the design is unsafe, since it reads past the matrix; a gain over fewer reads inside it. The help sentence is at `R/calc_power_gsd.R:29-31`.

**Code showing the problem** ([`reprex/C21.R`](reprex/C21.R)):

```r
# C21: calc_power_pvals_gsd() refuses a gain that does not mention the last hypothesis
# Run: Rscript C21.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

set.seed(1)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), info_frac = c(0.5, 1), nsim = 2000)
pvals <- transform_pvalues_gsd(raw, spending = sfLDOF, grid_size = 128L)
w <- c(0.5, 0.5)
G <- matrix(c(0, 1, 1, 0), 2)

# power to reject H1 at the interim, on a design with two hypotheses
h1_interim <- trial_success_gsd((t1 == 1) + 0, verbose = "silent")
res <- tryCatch(calc_power_pvals_gsd(pvals, w, G, custom_power = list(g = h1_interim))$g,
                error = function(e) conditionMessage(e))
cat("gain (t1 == 1) + 0:         ", res, "\n")

padded <- trial_success_gsd((t1 == 1) + 0 * r2, verbose = "silent")
cat("gain (t1 == 1) + 0 * r2:    ", calc_power_pvals_gsd(pvals, w, G, custom_power = list(g = padded))$g, "\n")
cat("local power of H1, analysis 1:", calc_power_pvals_gsd(pvals, w, G)$local_power_by_analysis[1, 1], "\n")
cat("EXPECTED: the same number from all three lines\n")
```

Output on `gsd-build`:

```
gain (t1 == 1) + 0:          `custom_power$g` and `pvals` disagree on the number of hypotheses.
✖ The trial success function is defined over m = 1, but the p-values hold m =
  2.
gain (t1 == 1) + 0 * r2:     0.15
local power of H1, analysis 1: 0.15
EXPECTED: the same number from all three lines
```

**Potential fix.** Let `.gsd_check_gain_dims()` accept a narrower gain when the caller asks for it, and ask for it in `calc_power_pvals_gsd()` only, so that `graph_optimise_gsd()` keeps the strict check:

```diff
 .gsd_check_gain_dims <- function(
     trial_success,
     pvals,
+    allow_fewer = FALSE,
     arg = rlang::caller_arg(trial_success),
     call = rlang::caller_env()
 ) {
-    if (trial_success$m != pvals$m) {
+    if (
+        trial_success$m > pvals$m ||
+            (!allow_fewer && trial_success$m != pvals$m)
+    ) {
```

The call at `R/calc_power_gsd.R:137` gains `allow_fewer = TRUE`. This is not in the fix series and has no test there, so the script prints the same on both builds. It was tried only as a run-time patch on the unfixed build: `(t1 == 1) + 0` then gave 0.15, and a gain over 3 hypotheses was still refused. The alternative is to keep the check and correct the help sentence.

---

<a name="C22"></a>
## C22. is_graph_valid() stops on a missing value, and normalise_sum() keeps negative weights

- Functions: is_graph_valid(), normalise_sum(), calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patches 10, 11)

**What the error is.** `is_graph_valid(c(0.5, NA, 0.5), G)` stops with R's own "missing value where TRUE/FALSE needed"; an `NA` in the matrix does the same, and both power functions fail with the same words. Its help promises `FALSE` and a warning for a graph that fails a check, so code written as `if (!is_graph_valid(...))` is halted by an error that names no argument. `normalise_sum()` is exported to make weights valid for other tools. It returns 1000, -999 for `c(1, -0.999)` and 1.5, -0.5 for `c(-0.5, -0.5)`: the sum is 1 and the values are not weights. An `NA` in `x` gives the R error again.

**What causes it.** In `is_graph_valid()` the conditions `any(diag(trans_matrix) != 0)`, `any(hyp_weight < 0 | hyp_weight > 1)` and `any(trans_matrix < 0 | trans_matrix > 1)` (`R/utils.R:154, 163, 172`) are `NA` when a value is missing and no other value fails, and `if (NA)` is an error. The sum checks below them handle `NA` (`R/utils.R:181, 191`) and are never reached. `normalise_sum()` checks `x` for its type only (`R/utils.R:267`) and then rescales and fills the largest element with `target - sum(x[-anchor])`, whatever the signs (`R/utils.R:295-301`).

**Code showing the problem** ([`reprex/C22.R`](reprex/C22.R)):

```r
# C22: is_graph_valid() stops on a missing value; normalise_sum() keeps negative weights
# Run: Rscript C22.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

G <- rbind(c(0, 0.5, 0.5),
           c(0.5, 0, 0.5),
           c(0.5, 0.5, 0))
valid <- tryCatch(is_graph_valid(c(0.5, NA, 0.5), G), error = function(e) conditionMessage(e))
cat("is_graph_valid(c(0.5, NA, 0.5), G):", valid, "\n")

norm <- tryCatch(normalise_sum(c(1, -0.999)), error = function(e) conditionMessage(e))
cat("normalise_sum(c(1, -0.999)):       ", norm, "\n")
cat("EXPECTED: FALSE with a warning from is_graph_valid(), as its help says; an error from normalise_sum()\n")
```

Output on `gsd-build`:

```
is_graph_valid(c(0.5, NA, 0.5), G): missing value where TRUE/FALSE needed
normalise_sum(c(1, -0.999)):        1000 -999
EXPECTED: FALSE with a warning from is_graph_valid(), as its help says; an error from normalise_sum()
```

**Potential fix.** Make missing values a check of their own in `is_graph_valid()`, placed before the comparisons, and refuse in `normalise_sum()` what it cannot handle:

```r
# is_graph_valid()
if (anyNA(hyp_weight)) {
    warning("`hyp_weight` contains missing values.", call. = FALSE)
    return(FALSE)
}
if (anyNA(trans_matrix)) {
    warning("`trans_matrix` contains missing values.", call. = FALSE)
    return(FALSE)
}
# normalise_sum()
if (anyNA(x)) {
    cli::cli_abort("{.arg x} must not contain missing values.")
}
if (any(x < 0)) {
    negative <- as.character(which(x < 0))
    cli::cli_abort(c(
        "{.arg x} must not contain negative values.",
        x = "Negative at position{?s} {negative}."
    ))
}
```

With this change `is_graph_valid()` returns `FALSE` with the first warning, the power functions stop with "do not build a valid graph", and `normalise_sum()` stops with "`x` must not contain negative values". Nothing changes for non-negative weights without missing values. `normalise_sum(c(Inf, 1))` still gives the R error on the fixed build.

---

<a name="C23"></a>
## C23. An epsilon edge below about 1e-13 gives wrong local levels

- Functions: calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: suggested, not implemented

**What the error is.** A graph with "epsilon" edges is evaluated wrongly when the epsilon is typed too small. In the script two primaries pass `1 - e` to each other and `e` to their own secondary, so H3 holds half the level, 0.0125, once both primaries are rejected. With `e = 1e-6` the kernel agrees; with `e = 1.2e-16` H3 is rejected at p = 0.013 (level 8% too high); with `e = 1e-300` H3 is not rejected at p = 0.012 (level 0: the recycled alpha is lost). `is_graph_valid()` returns `TRUE` each time. Only hand-typed graphs are affected, since the optimiser sets edges below 1e-5 to 0 (`R/post_optim_processing.R:27-28`).

**What causes it.** The precision is lost before the kernel runs: `1 - 1.2e-16` is stored as the nearest double, `1 - 1.1e-16`, and `1 - 1e-300` as exactly 1. After a rejection the kernel divides by `1 - g_ij * g_ji` (`src/graph_shortcut.cpp:128-140`), which then has few correct digits or none; when it is exactly 0 the "degenerate case" branch sets the whole row to 0 (`src/graph_shortcut.cpp:143-148`).

**Code showing the problem** ([`reprex/C23.R`](reprex/C23.R)):

```r
# C23: an epsilon edge below about 1e-13 gives wrong local levels
# Run: Rscript C23.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Two primary hypotheses pass 1 - e to each other and e to their own secondary.
graph <- function(e) rbind(c(0, 1 - e, e, 0),
                           c(1 - e, 0, 0, e),
                           c(0, 1, 0, 0),
                           c(1, 0, 0, 0))
w <- c(0.5, 0.5, 0, 0)

# H1 and H2 are rejected (p = 0). H3 then holds alpha / 2 = 0.0125, whatever e is.
h3_rejected <- function(e, p3) {
    calc_power_pvals(rbind(c(0, 0, p3, 1)), w, graph(e))$local_power[3] == 1
}
for (e in c(1e-6, 1.2e-16, 1e-300)) {
    cat("e =", format(e), ": graph valid:", is_graph_valid(w, graph(e)),
        " H3 rejected at p = 0.012:", h3_rejected(e, 0.012),
        " at p = 0.013:", h3_rejected(e, 0.013), "\n")
}
cat("EXPECTED: TRUE at p = 0.012 and FALSE at p = 0.013 for every e, or a warning that the edge is too small\n")
```

Output on `gsd-build`:

```
e = 1e-06 : graph valid: TRUE  H3 rejected at p = 0.012: TRUE  at p = 0.013: FALSE
e = 1.2e-16 : graph valid: TRUE  H3 rejected at p = 0.012: TRUE  at p = 0.013: TRUE
e = 1e-300 : graph valid: TRUE  H3 rejected at p = 0.012: FALSE  at p = 0.013: FALSE
EXPECTED: TRUE at p = 0.012 and FALSE at p = 0.013 for every e, or a warning that the edge is too small
```

**Potential fix.** Leave the kernel alone and warn, in both power functions, when an edge is too small to act on:

```r
.warn_epsilon_edges <- function(trans_matrix, call = rlang::caller_env()) {
    loop <- trans_matrix * t(trans_matrix)                 # g_ij * g_ji
    near_one <- loop < 1 & 1 - loop < 1e-10
    lost <- loop == 1 & rowSums(trans_matrix > 0) > 1      # an edge next to a 1
    if (any(near_one | lost)) {
        cli::cli_warn(c(
            "{.arg trans_matrix} holds an edge too small for double precision.",
            i = "A product of two opposite edges is within 1e-10 of 1, so the \\
            levels after a rejection can be wrong. Use an edge of 1e-6 or more."
        ), call = call)
    }
    invisible(NULL)
}
```

This is not in the fix series and has no test there, so the script prints the same on both builds. Run on its own, the function warns for the script's graph at `e` of 1e-11 and below and is silent at 1e-10 and above and for six ordinary graphs. In a scan the level of H3 was right to 6 digits at `e = 1e-11` and off by 0.03% at `1e-13`.

---

<a name="ENV05"></a>
## ENV05. With a negative scipen option, or a deleted working directory, no gain can be built

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (the group sequential half on gsd-build only)
- Potential fix: tested (patches 28, 43, 44)

**What the error is.** Under `options(scipen = -5)` every call of either constructor stops with "Error 1 occurred building shared library" after raw compiler output (11 lines in the script); nothing names the option, which only controls how R prints numbers. A second session state has the same effect: if the working directory has been deleted, both constructors stop with "character argument expected" and leave the session in Rcpp's build directory.

**What causes it.** Three numbers are written in the session's format. A column index is a double (`R/trial_success.R:532`; `R/trial_success_gsd.R:851, 912, 919`) that `deparse1()` writes as `0e+00` (`R/trial_success.R:385`; `R/trial_success_gsd.R:802`), which the compiler accepts. A whole-number constant goes through `as.character()` and gains `.0` (`R/trial_success.R:543-546`): `2e+00.0`, which it rejects. Inside Rcpp, `sourceCpp()` turns its library counter into text with `as.character()` and names the exported function `sourceCpp_1e+00_powerFunc`, which stops every gain. For the working directory, `sourceCpp()` changes to its build directory and cannot change back when `getwd()` is `NULL`.

**Code showing the problem** ([`reprex/ENV05.R`](reprex/ENV05.R)):

```r
# ENV05: with a negative `scipen` option no gain can be built
# Run: Rscript ENV05.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

options(scipen = -5)     # a session set to print numbers in scientific notation
log <- capture.output(
    msg <- tryCatch({ trial_success(r1 + 2 * r2, verbose = "silent"); "built" },
                    error = function(e) conditionMessage(e))
)
options(scipen = 0)

cat("trial_success(r1 + 2 * r2) under options(scipen = -5):", msg, "\n")
cat("compiler output printed to the console:", length(log), "lines\n")
cat("generated C++ lines the compiler rejects:\n")
cat(sprintf("  %s\n", trimws(sub(" *//.*", "", grep("e\\+00", log, value = TRUE)))), sep = "")
cat("EXPECTED: the gain is built; `scipen` only controls how R prints numbers\n")
```

Output on `gsd-build`:

```
trial_success(r1 + 2 * r2) under options(scipen = -5): Error 1 occurred building shared library.
compiler output printed to the console: 11 lines
generated C++ lines the compiler rejects:
  13 |         total += (double(x(i, 0e+00)) + 2e+00.0 * double(x(i, 1e+00)));
  28 | RcppExport SEXP sourceCpp_1e+00_powerFunc(SEXP xSEXP) {
EXPECTED: the gain is built; `scipen` only controls how R prints numbers
```

**Potential fix.** Put indices and constants into the generated call as text (the formatter is shown under ENV01), keep `scipen` out of Rcpp's way while it compiles, and check the working directory first. In both constructors:

```r
.gsd_gain_cpp_index <- function(txt) {
    as.symbol(sprintf("%d", as.integer(sub("^[rt]", "", txt)) - 1L))
}

.trial_success_check_wd <- function(call = rlang::caller_env()) {
    if (is.null(getwd())) {
        cli::cli_abort("The working directory of this R session no \\
            longer exists, so the trial success function cannot be \\
            compiled.", call = call)
    }
}

.trial_success_check_wd()
withr::local_options(list(scipen = 999))
sourceCpp(code = cpp_code, env = local_env)
```

With this change the script prints "built" and no compiler output, and the user's `scipen` is back in place when the constructor returns. A deleted working directory gives the message above before anything is compiled, and the session is not moved. Nothing changes in a session with `scipen` of 0 or more.

---

<a name="MEM3"></a>
## MEM3. A kernel call cannot be interrupted

- Functions: calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (the group sequential kernels on gsd-build only)
- Potential fix: tested (patch 12)

**What the error is.** None of the four compiled kernels checks for a user interrupt, so Ctrl-C or Esc has no effect until the kernel call has returned. In the script one call of `calc_power_pvals()` on 10,000 trials of 64 hypotheses takes 3 to 6 s on the test machine, and an interrupt sent 0.5 s into a second call is acted on only when that call has done all its work. The work per trial grows with up to the cube of the number of hypotheses, so a mistaken call on a wide design, or with far more trials than intended, holds the session until it ends. No result is affected.

**What causes it.** There is no call of `Rcpp::checkUserInterrupt()` anywhere in `src/`. The serial trial loops run from the first trial to the last (`src/graph_shortcut.cpp:94`, `src/graph_shortcut_gsd.cpp:106`), and each parallel kernel makes one `parallelFor()` call over all trials (`src/graph_shortcut.cpp:362-363`, `src/graph_shortcut_gsd.cpp:408-409`).

**Code showing the problem** ([`reprex/MEM3.R`](reprex/MEM3.R)):

```r
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
```

Output on `gsd-build`:

```
one uninterrupted call takes 3.1 s
interrupt sent at 0.5 s, acted on at 3.2 s
the call ran to its end before the interrupt was seen: TRUE
EXPECTED: the call abandoned shortly after 0.5 s (FALSE in the line above)
```

**Potential fix.** Run the trials in stretches and check between stretches. In the serial kernels (shown after the MEM1 change of types):

```cpp
// about 5e7 inner-loop operations between two checks
const R_xlen_t check_every = std::max<R_xlen_t>(
  1,
  static_cast<R_xlen_t>(5e7 / std::max(1.0, static_cast<double>(m) * m * m))
);

for (R_xlen_t block = 0; block < N; block += check_every) {
  if (block > 0)
    Rcpp::checkUserInterrupt();
  const R_xlen_t block_end = std::min(N, block + check_every);

  for (R_xlen_t set = block; set < block_end; ++set) {
    // the body of the trial loop, unchanged
  }
}
```

The parallel kernels call `parallelFor()` on blocks of about 2e8 operations with the same check between blocks. With this change the script reports the interrupt acted on at 0.5 to 0.6 s and the call abandoned. A call shorter than one stretch makes no check at all. The series marks this patch as optional, since it restructures the hot loop. Its effect on speed was not measured for this entry. The script uses `kill` and was run on Linux only.

---

<a name="DOC12"></a>
## DOC12. The error for `r1 + r2 && r3` does not say that parentheses are needed

- Functions: trial_success_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 40)

**What the error is.** `trial_success_gsd(r1 + r2 && r3)` stops with "`&&` (AND) only allowed between booleans." and nothing else. The user sees `&&` between `r2` and `r3`, which are booleans, so the message reads as false. `trial_success()` documents that it compiles the same expression as `r1 + (r2 && r3)` (`R/trial_success.R:71-72`), so a gain moved to the group sequential constructor can meet this error first. The design record promises more: it says the rule rejects this expression "with an error asking for parentheses" (`dev/gsd_design_record.md:184`).

**What causes it.** `trial_success_gsd()` keeps R's precedence, under which `&&` binds less tightly than `+`: R reads `(r1 + r2) && r3`, and the left operand is a number. `.gsd_gain_transform_call()` reports the rule it applied, with `stop(what, " only allowed between booleans.")` (`R/trial_success_gsd.R:864-867`), and not how the expression was grouped.

**Code showing the problem** ([`reprex/DOC12.R`](reprex/DOC12.R)):

```r
# DOC12: the error for `r1 + r2 && r3` does not say that parentheses are needed
# Run: Rscript DOC12.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Meant: r1 + (r2 && r3). R reads it as (r1 + r2) && r3.
msg <- tryCatch(trial_success_gsd(r1 + r2 && r3, K = 2, verbose = "silent"),
                error = function(e) conditionMessage(e))
cat("error message:\n")
cat(msg, "\n")
cat("mentions parentheses:", grepl("parenthes", msg), "\n")
cat("EXPECTED: a message that says how R grouped the expression and where to put parentheses\n")
```

Output on `gsd-build`:

```
error message:
`&&` (AND) only allowed between booleans.
mentions parentheses: FALSE
EXPECTED: a message that says how R grouped the expression and where to put parentheses
```

**Potential fix.** Keep the first line and add a hint that names the grouping and the cure. In `.gsd_gain_transform_call()` (`R/trial_success_gsd.R`):

```r
if (left$type != "bool" || right$type != "bool") {
    what <- if (op_text == "&&") "`&&` (AND)" else "`||` (OR)"
    cli::cli_abort(
        c(
            "{what} only allowed between booleans.",
            i = "R reads {.code a + b {op_text} c} as \\
            {.code (a + b) {op_text} c}, so each logical term needs \\
            its own parentheses: {.code a + (b {op_text} c)}."
        ),
        call = NULL
    )
}
```

With this change the script prints the old first line followed by "R reads `a + b && c` as `(a + b) && c`, so each logical term needs its own parentheses: `a + (b && c)`." The error is now an rlang error with a bullet where it was a simple error; code that matches the first line is unaffected. The message of `trial_success()` is left alone: its parser groups the expression the other way, so the hint would be false there.

---

<a name="DOC14"></a>
## DOC14. Replacing any other element of a graph constraint gives "object 'output' not found"

- Functions: graph_constraint() (the replacement methods `$<-`, `[[<-` and `[<-` of its objects)
- Branches: main and gsd-build
- Potential fix: tested (patch 57)

**What the error is.** A graph constraint lets the user replace `hyp_constraint` and `trans_constraint` in place, and re-validates the object when they do. Any other replacement, such as `con$tolerance <- 1e-6`, `con$note <- "x"`, `con[["names"]] <- ...` or `con[[1]] <- ...`, stops with "object 'output' not found". The message is an internal slip and does not say which elements can be replaced, or that the tolerance and the names are arguments of `graph_constraint()`.

**What causes it.** `[[<-.multigrain_graph_constraint` assigns `output` inside one of two branches, `if (i == "hyp_constraint")` and `if (i == "trans_constraint")`, and then returns it (`R/graph_constraint.R:391-413`). For any other `i` neither branch runs and the last line evaluates a variable that was never created. `$<-` and `[<-` call the same method (`R/graph_constraint.R:363-367, 417-421`).

**Code showing the problem** ([`reprex/DOC14.R`](reprex/DOC14.R)):

```r
# DOC14: replacing any other element of a graph constraint gives "object 'output' not found"
# Run: Rscript DOC14.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

con <- graph_constraint(hyp_constraint = c(NA, 0.4, NA))

# the documented route works
con$hyp_constraint <- c(NA, NA, NA)
cat("con$hyp_constraint <- c(NA, NA, NA): weights now", paste(con$hyp_constraint, collapse = " "), "\n")

# a slip: the tolerance is an argument of graph_constraint(), not an element
msg <- tryCatch({
    con$tolerance <- 1e-6
    "accepted"
}, error = function(e) conditionMessage(e))
cat("con$tolerance <- 1e-6:", msg, "\n")
cat("EXPECTED: an error saying that only hyp_constraint and trans_constraint can be replaced\n")
```

Output on `gsd-build`:

```
con$hyp_constraint <- c(NA, NA, NA): weights now NA NA NA
con$tolerance <- 1e-6: object 'output' not found
EXPECTED: an error saying that only hyp_constraint and trans_constraint can be replaced
```

**Potential fix.** Check `i` at the top of the method and say what can be replaced.

```r
`[[<-.multigrain_graph_constraint` <- function(x, i, ..., value) {
    if (!rlang::is_string(i, c("hyp_constraint", "trans_constraint"))) {
        cli::cli_abort(
            "Only the {.field hyp_constraint} and {.field trans_constraint} \\
            elements of a graph constraint can be replaced, one at a time \\
            and by name."
        )
    }
    # ... the rest of the method is unchanged
```

With this change the script stops with that message. Replacing either of the two elements by name works as before. One form is not changed: `con["hyp_constraint"] <- list(value)`, the list form of `[<-`, still stops in `graph_constraint()` with "`hyp_constraint` must be a double or `NA`, not a list".

---

<a name="DOC17b"></a>
## DOC17b. Integer weights are refused although hyp_weight is documented as numeric

- Functions: calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 14)

**What the error is.** `calc_power_pvals(pvals, c(1L, 0L), G)` stops with "`hyp_weight` must be a double, not an integer vector", and an integer `trans_matrix` with "must be a double matrix, not an integer matrix". The help describes the two arguments as "a numeric vector" and "a numeric matrix", and `is_graph_valid()` accepts the same integer input and returns `TRUE`. A fixed sequence holds only the values 0 and 1, so integer input is easy to produce, for example with `c(1L, 0L)` or from a matrix read from a file. The user is told that a valid graph has the wrong type.

**What causes it.** `check_double(hyp_weight)` and `check_double_matrix(trans_matrix)` (`R/calc_power.R:125-126`, `R/calc_power_gsd.R:110-111`) rest on `rlang::is_double()` (`R/check_types.R:17, 49`), which is `FALSE` for an integer vector. The help text is inherited from `is_graph_valid()` (`R/utils.R:78, 81`).

**Code showing the problem** ([`reprex/DOC17b.R`](reprex/DOC17b.R)):

```r
# DOC17b: integer weights are refused although hyp_weight is documented as numeric
# Run: Rscript DOC17b.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8), nsim = 500)
G <- matrix(c(0, 1, 1, 0), 2)

cat("hyp_weight = c(1, 0):  ", calc_power_pvals(pvals, c(1, 0), G)$local_power, "\n")
int <- tryCatch(calc_power_pvals(pvals, c(1L, 0L), G)$local_power,
                error = function(e) conditionMessage(e))
cat("hyp_weight = c(1L, 0L):", int, "\n")
cat("is_graph_valid(c(1L, 0L), G):", is_graph_valid(c(1L, 0L), G), "\n")
cat("EXPECTED: the same local power from both calls\n")
```

Output on `gsd-build`:

```
hyp_weight = c(1, 0):   0.89 0.704
hyp_weight = c(1L, 0L): `hyp_weight` must be a double, not an integer vector.
is_graph_valid(c(1L, 0L), G): TRUE
EXPECTED: the same local power from both calls
```

**Potential fix.** Convert integers before the two checks, in both power functions:

```r
# Both are documented as numeric: whole numbers typed as integers, such as
# `c(1L, 0L)`, are converted, not refused
if (!missing(hyp_weight) && is.integer(hyp_weight)) {
    storage.mode(hyp_weight) <- "double"
}
if (!missing(trans_matrix) && is.integer(trans_matrix)) {
    storage.mode(trans_matrix) <- "double"
}
check_double(hyp_weight)
check_double_matrix(trans_matrix)
```

With this change both calls of the script print the same local power, 0.89 and 0.704. `storage.mode<-` keeps names and dimnames. Other types are refused as before, and nothing changes for double input. The alternative is to leave the check and write "double" in the help.

---

<a name="DOC17c"></a>
## DOC17c. normalise_sum() accepts a negative tolerance

- Functions: normalise_sum()
- Branches: main and gsd-build
- Potential fix: tested (patch 11)

**What the error is.** The help of `normalise_sum()` gives `tolerance` as "numeric >= 0", yet any number is accepted. With the help's own example, `c(0.25, 0.45, 0.30)` and elements 1 and 3 held fixed, `tolerance = -1` stops with "Fixed elements sum to 0.55 which exceeds target (1)". That statement is false and it sends the user to the wrong argument. Without fixed elements a negative tolerance is accepted in silence, and `c(0.2, 0.3, 0.6)` gives the same result as with the default. The cost is small, but the function is exported and its sibling `is_graph_valid()` does refuse a negative tolerance.

**What causes it.** `rlang::check_number_decimal(tolerance)` is called without `min` (`R/utils.R:271`), where `is_graph_valid()` has `min = 0` (`R/utils.R:126`). The test `target_free < -tolerance` (`R/utils.R:284`) then compares with +1 when the tolerance is -1, so fixed elements that leave less than 1 for the others raise the "exceeds target" error.

**Code showing the problem** ([`reprex/DOC17c.R`](reprex/DOC17c.R)):

```r
# DOC17c: normalise_sum() accepts a negative tolerance
# Run: Rscript DOC17c.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- c(0.25, 0.45, 0.30)                     # the help example: elements 1 and 3 are fixed
cat("default tolerance:", normalise_sum(x, fixed_idx = c(1L, 3L)), "\n")

neg <- tryCatch(normalise_sum(x, fixed_idx = c(1L, 3L), tolerance = -1),
                error = function(e) conditionMessage(e))
cat("tolerance = -1:   ", neg, "\n")
cat("EXPECTED: an error saying that `tolerance` must be at least 0 (the help says \"numeric >= 0\")\n")
```

Output on `gsd-build`:

```
default tolerance: 0.25 0.45 0.3
tolerance = -1:    Fixed elements sum to 0.55 which exceeds target (1). Cannot normalise: reduce fixed element values or increase target.
EXPECTED: an error saying that `tolerance` must be at least 0 (the help says "numeric >= 0")
```

**Potential fix.** Give the check its lower bound:

```diff
-    rlang::check_number_decimal(tolerance)
+    rlang::check_number_decimal(tolerance, min = 0)
```

With this change the script prints "`tolerance` must be a number larger than or equal to 0, not the number -1." Nothing changes for a tolerance of 0 or more. The line is part of patch 11, which also carries the `normalise_sum()` half of C22 and the fix of DOC17d: the three are separate entries here since they concern different arguments and different lines.

---

<a name="DOC17d"></a>
## DOC17d. normalise_sum() does not check fixed_idx against the length of x

- Functions: normalise_sum()
- Branches: main and gsd-build
- Potential fix: tested (patch 11)

**What the error is.** `fixed_idx` holds the positions of the elements that must not be modified. A position beyond the vector, `fixed_idx = 7L` on three elements, stops with R's own "missing value where TRUE/FALSE needed", which names nothing. A negative position is worse: it is accepted and gives a wrong result with no message. `normalise_sum(c(0.2, 0.3, 0.6), fixed_idx = -1L)` returns 0.018, 0.027, 0.955, where plain normalisation gives 0.182, 0.273, 0.545. No element is held fixed and the proportions between the weights are lost; a position of 0 is ignored in silence.

**What causes it.** `check_integerish(fixed_idx)` looks at the type only (`R/utils.R:269`). For a position beyond the vector `x[fixed_idx]` is `NA`, so `target_free` is `NA` and `if (target_free < -tolerance)` fails (`R/utils.R:283-284`). For `-1L`, `setdiff(seq_along(x), fixed_idx)` removes nothing and every element stays free (`R/utils.R:277`), while `x[fixed_idx]` is R's "all but the first" and its sum, 0.9, is taken as the fixed total (`R/utils.R:283`).

**Code showing the problem** ([`reprex/DOC17d.R`](reprex/DOC17d.R)):

```r
# DOC17d: normalise_sum() does not check fixed_idx against the length of x
# Run: Rscript DOC17d.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- c(0.2, 0.3, 0.6)
cat("no fixed element:", normalise_sum(x), "\n")

beyond <- tryCatch(normalise_sum(x, fixed_idx = 7L), error = function(e) conditionMessage(e))
cat("fixed_idx = 7L:  ", beyond, "\n")

negative <- tryCatch(normalise_sum(x, fixed_idx = -1L), error = function(e) conditionMessage(e))
cat("fixed_idx = -1L: ", negative, "\n")
cat("EXPECTED: an error naming `fixed_idx` in both cases: positions run from 1 to 3\n")
```

Output on `gsd-build`:

```
no fixed element: 0.1818182 0.2727273 0.5454545
fixed_idx = 7L:   missing value where TRUE/FALSE needed
fixed_idx = -1L:  0.01818182 0.02727273 0.9545455
EXPECTED: an error naming `fixed_idx` in both cases: positions run from 1 to 3
```

**Potential fix.** Refuse a position outside the vector, after the type check:

```r
if (anyNA(fixed_idx) || any(fixed_idx < 1 | fixed_idx > length(x))) {
    cli::cli_abort(
        "{.arg fixed_idx} must hold positions between 1 and \\
        {length(x)}, the length of {.arg x}."
    )
}
```

With this change both calls of the script stop with "`fixed_idx` must hold positions between 1 and 3, the length of `x`." Nothing changes for valid positions. A repeated position is still accepted, since the pruning code passes the diagonal position twice (`R/post_optim_processing.R:31`); its value is then counted twice in the fixed total, so `fixed_idx = c(1L, 1L)` on the same vector returns 0.2, 0.2, 0.6 on both builds. That is harmless for a diagonal entry, which is 0.

---

<a name="DOC17f"></a>
## DOC17f. plot(x, root = 7) on a graph with 4 hypotheses gives a raw igraph error

- Functions: plot() and autoplot() of a result and of a graph constraint
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** The help describes `root` as "a numeric vector indicating which nodes to be regarded as root" and does not say that the numbers must be existing nodes. `plot(graph_optimal_example, root = 7)` on the bundled 4-hypothesis graph stops with "At core/layout/reingold_tilford.c:809 : Invalid vertex id". `root = 0` gives the same message, `root = c(1, 7)` a different C-level one, and `root = NA_integer_` gives "Invalid vertex name(s)". None of them names the argument or the valid range. The plot of a graph constraint behaves the same way.

**What causes it.** Both `autoplot()` methods check only that `root` is integer-like (`R/plot_graph_optimal.R:45`, `R/plot_graph_constraint.R:51`) and pass it on. `create_layout()` hands it to `igraph::layout_as_tree(graph, root = root)` unchanged (`R/plot_graph_optimal.R:194-199`), so the range error is raised inside igraph's C code.

**Code showing the problem** ([`reprex/DOC17f.R`](reprex/DOC17f.R)):

```r
# DOC17f: plot(x, root = 7) on a graph with 4 hypotheses gives a raw igraph error
# Run: Rscript DOC17f.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

pdf(NULL)
cat("hypotheses in the bundled example graph:", length(graph_optimal_example$hyp_weight), "\n")

# the help example: nodes 1 and 2 as root
p <- plot(graph_optimal_example, root = c(1, 2))
cat("plot(graph_optimal_example, root = c(1, 2)): works, class", class(p)[1], "\n")

# a node that does not exist
msg <- tryCatch({
    plot(graph_optimal_example, root = 7)
    "accepted"
}, error = function(e) conditionMessage(e))
cat("plot(graph_optimal_example, root = 7):", msg, "\n")
cat("EXPECTED: an error saying that `root` must lie between 1 and 4\n")
```

Output on `gsd-build`:

```
hypotheses in the bundled example graph: 4
plot(graph_optimal_example, root = c(1, 2)): works, class ggraph
plot(graph_optimal_example, root = 7): At core/layout/reingold_tilford.c:809 : Invalid vertex id. Invalid vertex id
EXPECTED: an error saying that `root` must lie between 1 and 4
```

**Potential fix.** Check the range in `create_layout()`, the one place both methods pass through, before igraph is called.

```r
create_layout <- function(graph, nodes, edges, root = NULL,
                          call = rlang::caller_env()) {
    if (is.null(root)) {
        root <- estimate_root(nodes, edges)
    } else if (anyNA(root) || any(root < 1 | root > nrow(nodes))) {
        cli::cli_abort(
            "{.arg root} must hold hypothesis numbers between 1 and \\
            {nrow(nodes)}, not {.val {root}}.",
            call = call
        )
    }

    tree_layout <- igraph::layout_as_tree(graph, root = root)
    # ... the rest is unchanged
```

This is a suggestion: it is not in the patch series, has no test, and the script prints the same on the fixed build as on the unfixed one. Tried once by patching `create_layout()` in a loaded session, `root = 7` stopped with "`root` must hold hypothesis numbers between 1 and 4, not 7", reported from `autoplot()`; `root = 0`, `c(1, 7)` and `NA_integer_` were refused in the same words, and `root = c(1, 2)` and the default still drew the plot, for a result and for a constraint. The help text of `root` should state the range too.

---

<a name="DOC17g"></a>
## DOC17g. sum_to_one_constraint = NA gives R's own error, not a message about the argument

- Functions: is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd()
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 10)

**What the error is.** `is_graph_valid(w, G, sum_to_one_constraint = NA)` stops with "missing value where TRUE/FALSE needed", and `c(TRUE, FALSE)` with "the condition has length > 1". Neither message names the argument, and both power functions pass the flag on and fail with the same words. The help of `is_graph_valid()` says that a failed check gives `FALSE` and a warning. For an unusable flag an error is the right outcome, but it should say which argument is at fault. `NA` arises easily when the flag is computed, for example from a comparison that involves a missing value.

**What causes it.** `check_logical(sum_to_one_constraint)` (`R/utils.R:125`, `R/calc_power.R:129`, `R/calc_power_gsd.R:114`) accepts a logical vector of any length and, with its default `allow_na = TRUE`, missing values (`R/import-standalone-types-check.R:313-335`). The flag is then used as the condition of `if (sum_to_one_constraint)` (`R/utils.R:189`).

**Code showing the problem** ([`reprex/DOC17g.R`](reprex/DOC17g.R)):

```r
# DOC17g: sum_to_one_constraint = NA gives R's own error, not a message about the argument
# Run: Rscript DOC17g.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(0.5, 0.5)
G <- matrix(c(0, 1, 1, 0), 2)

na <- tryCatch(is_graph_valid(w, G, sum_to_one_constraint = NA),
               error = function(e) conditionMessage(e))
cat("sum_to_one_constraint = NA:            ", na, "\n")
two <- tryCatch(is_graph_valid(w, G, sum_to_one_constraint = c(TRUE, FALSE)),
                error = function(e) conditionMessage(e))
cat("sum_to_one_constraint = c(TRUE, FALSE):", two, "\n")
cat("EXPECTED: an error saying that `sum_to_one_constraint` must be TRUE or FALSE\n")
```

Output on `gsd-build`:

```
sum_to_one_constraint = NA:             missing value where TRUE/FALSE needed
sum_to_one_constraint = c(TRUE, FALSE): the condition has length > 1
EXPECTED: an error saying that `sum_to_one_constraint` must be TRUE or FALSE
```

**Potential fix.** Check for a single `TRUE` or `FALSE` in `is_graph_valid()`, through which both power functions pass:

```diff
-    check_logical(sum_to_one_constraint)
+    rlang::check_bool(sum_to_one_constraint)
```

With this change the script prints "`sum_to_one_constraint` must be `TRUE` or `FALSE`, not `NA`." and "... not a logical vector." The power functions give the same message, since the argument has the same name there. Nothing changes for `TRUE` or `FALSE`. The line is part of patch 10, whose other half (missing values in the weights or the matrix) is entry C22: a different argument and different lines, so the two are kept apart.
