# Severity 4: documentation, printing, housekeeping, and internal routines no user reaches

Nothing here changes a number a user computes with the package's functions. DOC1 is the exception to keep in mind: the article it concerns leads a reader to a different design from the one described.

23 entries. Back to the [index](README.md).

Contents: [MEM4](#MEM4), [D_ggplot2_optional](#D_ggplot2_optional), [D_global_output](#D_global_output), [D_graphics_undeclared](#D_graphics_undeclared), [D_local_weights](#D_local_weights), [D_plot_rounding](#D_plot_rounding), [D_power_nominal](#D_power_nominal), [DOC1](#DOC1), [DOC2](#DOC2), [DOC3](#DOC3), [DOC4](#DOC4), [DOC6](#DOC6), [DOC7](#DOC7), [DOC8](#DOC8), [DOC9](#DOC9), [DOC10](#DOC10), [DOC11](#DOC11), [DOC13](#DOC13), [DOC15](#DOC15), [DOC16](#DOC16), [DOC17a](#DOC17a), [DOC17h](#DOC17h), [REG3](#REG3)

---

<a name="MEM4"></a>
## MEM4. Two internal routines lack a guard: an out-of-bounds read and a division by zero

- Functions: none exported (internal graph_violation_score_cpp(), graph_shortcut_parallel(), graph_shortcut_gsd_parallel())
- Branches: main and gsd-build (graph_shortcut_gsd_parallel() on gsd-build only)
- Potential fix: tested (patches 8, 9)

**What the error is.** Two pieces of undefined behaviour that no exported function reaches today. First, `graph_violation_score_cpp(w, G)` reads `G(i, j)` for every `i` and `j` below `length(w)` without looking at the size of `G`: with 20 weights and a 5 x 5 matrix it returns a score and no error, 5 in some sessions here and 5.24e+284 in others, since the number comes from the memory behind the matrix. Nothing in `R/` calls this function; the tests do. Second, the parallel kernels choose their grain size by dividing 100,000 by `m^3`, which with zero hypotheses is a division by zero whose infinite result is converted to an unsigned integer; a direct call returned a 5 x 0 matrix here, so nothing is visible on this platform. Both are traps for later code, not for today's user.

**What causes it.** `src/optimization-helpers.cpp:18-39`: `m` is taken from `w.size()` alone, and `G(i, j)` is unchecked Rcpp indexing. `src/graph_shortcut.cpp:332-338` and `src/graph_shortcut_gsd.cpp:376-382`: `static_cast<std::size_t>(TARGET_OPS / ops_per_row)` with `ops_per_row` equal to `m * m * m` (times `K` in the group sequential kernel). `calc_power_pvals()` refuses a design without hypotheses, and `graph_constraint_free()` needs at least 2.

**Code showing the problem** ([`reprex/MEM4.R`](reprex/MEM4.R)):

```r
# MEM4: graph_violation_score_cpp() reads past a transition matrix smaller than the weight vector
# Run: Rscript MEM4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- rep(1 / 20, 20)                      # 20 hypotheses
G_small <- matrix(0.25, 5, 5)             # a matrix for 5
G_right <- matrix(0.25, 20, 20)

score <- tryCatch(multigrain:::graph_violation_score_cpp(w, G_small),
                  error = function(e) conditionMessage(e))
cat("score with the 5 x 5 matrix:  ", format(score), "\n")
cat("an error was raised:          ", is.character(score), "\n")
cat("score with a 20 x 20 matrix:  ", multigrain:::graph_violation_score_cpp(w, G_right), "\n")
cat("EXPECTED: an error for the 5 x 5 matrix, which is too small for 20 weights\n")
```

Output on `gsd-build`:

```
score with the 5 x 5 matrix:   5
an error was raised:           FALSE
score with a 20 x 20 matrix:   80
EXPECTED: an error for the 5 x 5 matrix, which is too small for 20 weights
```

**Potential fix.** One guard for each:

```cpp
// graph_violation_score_cpp(), after m is set
if (G.nrow() != m || G.ncol() != m)
  stop("G must be an m x m matrix matching length(w).");

// graph_shortcut_parallel(); with K as a further factor in the GSD kernel
double ops_per_row = std::max(1.0, static_cast<double>(m) * m * m);
```

With this change the script prints that error message for the 5 x 5 matrix. For one hypothesis or more the product is at least 1 already, so the grain size is what it was. The second guard has no observable effect on this platform, before or after.

---

<a name="D_ggplot2_optional"></a>
## D_ggplot2_optional. The plot help calls ggplot2 an optional dependency, but the package cannot be loaded without it

- Functions: plot() and autoplot() for graph constraints and optimised graphs
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** The help pages of the two plot methods say: "Both `plot()` and `autoplot()` methods require an optional dependency, ggplot2." ggplot2 is not optional. It is listed under Imports, the namespace imports `autoplot` from it, and the methods call `ggplot2::` functions directly, so it is installed with multigrain and multigrain cannot be loaded without it. A reader is led to think that plotting needs a separate installation. What the user does have to do goes unsaid: `plot()` works at once, but `autoplot()` stops with "could not find function "autoplot"" until ggplot2 is attached, since multigrain does not re-export the generic. The examples attach it without comment.

**What causes it.** The sentence is in the roxygen blocks of both methods: `R/plot_graph_optimal.R:4-5` and `R/plot_graph_constraint.R:4-5`. It contradicts `DESCRIPTION:22` (ggplot2 under Imports) and `NAMESPACE:47` (`importFrom(ggplot2,autoplot)`, from `R/multigrain-package.R:8`). All of these lines date from the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/D_ggplot2_optional.R`](reprex/D_ggplot2_optional.R)):

```r
# D_ggplot2_optional: the plot help calls ggplot2 an optional dependency; the package cannot load without it
# Run: Rscript D_ggplot2_optional.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["autoplot.multigrain_graph_optimal.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("require an optional", txt)
cat("help page says:", trimws(txt[i + 0:1]), "\n")

imports <- packageDescription("multigrain")$Imports
cat("ggplot2 under Imports in DESCRIPTION  :", grepl("ggplot2", imports), "\n")
cat("imported from ggplot2 by the NAMESPACE:", getNamespaceImports("multigrain")$ggplot2, "\n")
method <- deparse(multigrain:::autoplot.multigrain_graph_optimal)
cat("the autoplot method calls ggplot2::     :", any(grepl("ggplot2::", method)), "\n")

# What a user does have to do: attach ggplot2 before calling autoplot().
msg <- tryCatch(autoplot(graph_optimal_example), error = function(e) conditionMessage(e))
cat("autoplot() without library(ggplot2)   :", msg, "\n")
cat("EXPECTED: the help does not call a hard dependency optional, and says that\n")
cat("          autoplot() needs library(ggplot2)\n")
```

Output on `gsd-build`:

```
help page says: Both ‘plot()’ and ‘autoplot()’ methods require an optional dependency, ggplot2.
ggplot2 under Imports in DESCRIPTION  : TRUE
imported from ggplot2 by the NAMESPACE: autoplot
the autoplot method calls ggplot2::     : TRUE
autoplot() without library(ggplot2)   : could not find function "autoplot"
EXPECTED: the help does not call a hard dependency optional, and says that
          autoplot() needs library(ggplot2)
```

**Potential fix.** Say what is true and what the user needs to do. In both files:

```diff
 #' @details
-#' Both `plot()` and `autoplot()` methods require an optional dependency,
-#' [ggplot2][ggplot2::ggplot2-package].
+#' Both methods build the plot with [ggplot2][ggplot2::ggplot2-package], which
+#' is installed with multigrain. `plot()` can be called at once. To call
+#' `autoplot()`, attach ggplot2 first with `library(ggplot2)`.
```

then regenerate the help pages. This has not been implemented or tested. After it the first line of the script prints nothing after "help page says:", since the sentence it looks for is gone. The alternative, which removes the need for `library(ggplot2)`, is to re-export the generic from `R/multigrain-package.R`; that is not tested either.

---

<a name="D_global_output"></a>
## D_global_output. result$global_output is an invalid S4 object and cannot be printed

- Functions: graph_optimise(), graph_optimise_gsd()
- Branches: main and gsd-build (graph_optimise_gsd() on gsd-build only)
- Potential fix: tested (patch 58)

**What the error is.** The result of an optimisation carries `global_output`, documented as "Output from the genetic algorithm". Printing it stops with 'no slot of name "call" for this object of class "ga"', `validObject()` fails on it, and `str()` of the whole result warns. `summary()` of the object still works. A user who wants to look at the convergence of the global search meets an error from the methods package.

**What causes it.** `graph_optimal()` drops the recorded call to keep the result small, with `attr(global_output, "call") <- NULL` (`R/graph_optimal.R:63-65`). The call holds every argument of `GA::ga()`, the fitness closure and its p-values among them, so removing it is reasonable. The slots of an S4 object are stored as attributes, though, so this line removes the `call` slot itself and leaves an object that no longer matches its class definition.

**Code showing the problem** ([`reprex/D_global_output.R`](reprex/D_global_output.R)):

```r
# D_global_output: result$global_output is an invalid S4 object and cannot be printed
# Run: Rscript D_global_output.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
P <- simulate_pvalues(c(0.9, 0.8, 0.7), nsim = 1000)
gain <- trial_success(r1 + r2 + r3, verbose = "silent")
ctrl <- control_global(multigrain_control(), popSize = 20, maxiter = 15, run = 5)
res <- graph_optimise(P, graph_constraint_free(3), gain, control = ctrl, verbose = "silent")

ga <- res$global_output            # documented as "Output from the genetic algorithm"
cat("class:", class(ga), "  has its `call` slot:", methods::.hasSlot(ga, "call"), "\n")

msg <- tryCatch({
    utils::capture.output(print(ga))
    "printed"
}, error = function(e) conditionMessage(e))
cat("print(res$global_output):", msg, "\n")
cat("EXPECTED: a valid `ga` object that prints\n")
```

Output on `gsd-build`:

```
class: ga   has its `call` slot: FALSE
print(res$global_output): no slot of name "call" for this object of class "ga"
EXPECTED: a valid `ga` object that prints
```

**Potential fix.** Keep the slot and store an empty call in it.

```diff
-    # remove the @call slot from the global output. GA outputs are S4 objects
-    # and the @call slot is recorded as an attribute
-    attr(global_output, "call") <- NULL
+    # empty the @call slot: it records every argument of the GA::ga() call.
+    # The slot itself has to stay, or the S4 object is invalid.
+    if (isS4(global_output)) {
+        global_output@call <- call("ga")
+    }
```

With this change the script reports that the slot is present and that the object prints. Every other slot is untouched. Results saved before the change, the bundled `graph_optimal_example` included, keep the invalid form.

---

<a name="D_graphics_undeclared"></a>
## D_graphics_undeclared. The namespace imports plot from graphics, which DESCRIPTION does not declare

- Functions: plot() for graph constraints and optimised graphs
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** `NAMESPACE` imports from five packages: Rcpp, RcppParallel, ggplot2, rlang and graphics. The first four are declared in `DESCRIPTION`; graphics is not, although the base packages stats and utils are listed under Imports. Nothing fails for a user: graphics is part of every R installation, and R's own dependency check (`tools:::.check_package_depends()`, the one `R CMD check` runs) reports nothing for this tree. It is an inconsistency in the package metadata and nothing more.

**What causes it.** `R/multigrain-package.R:9` has `#' @importFrom graphics plot`, which roxygen writes to `NAMESPACE:48`. The matching entry in `DESCRIPTION:18-38` was never added. The import is also no longer needed for its purpose: since R 4.0.0 the `plot()` generic lives in base (R's NEWS for 4.0.0; the script prints `base` as its home in the R used here), and the package requires R 4.1.0 or later, so the two `S3method(plot, ...)` registrations find the generic without it. The line dates from the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/D_graphics_undeclared.R`](reprex/D_graphics_undeclared.R)):

```r
# D_graphics_undeclared: plot is imported from graphics, which DESCRIPTION does not declare
# Run: Rscript D_graphics_undeclared.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

imp <- getNamespaceImports("multigrain")
used <- setdiff(unique(names(imp)), "base")
d <- packageDescription("multigrain")
declared <- sub("\\s*\\(.*", "", trimws(strsplit(paste(d$Imports, d$Depends, sep = ","), ",")[[1]]))

cat("namespaces the package imports from:", paste(sort(used), collapse = ", "), "\n")
cat("imported and not declared in DESCRIPTION:", setdiff(used, declared), "\n")
cat("what is imported from it:", unlist(imp[names(imp) == "graphics"]), "\n")
cat("where the plot() generic lives in this R:", environmentName(environment(plot)), "\n")
cat("EXPECTED: every namespace in NAMESPACE is under Imports, as stats and utils are\n")
```

Output on `gsd-build`:

```
namespaces the package imports from: ggplot2, graphics, Rcpp, RcppParallel, rlang
imported and not declared in DESCRIPTION: graphics
what is imported from it: plot
where the plot() generic lives in this R: base
EXPECTED: every namespace in NAMESPACE is under Imports, as stats and utils are
```

**Potential fix.** Declare what is imported. In `DESCRIPTION`:

```diff
     ggraph,
     glue,
+    graphics,
     gsDesign,
     igraph,
```

This has not been implemented or tested. After it the script prints nothing after "imported and not declared in DESCRIPTION:". It changes nothing for a user. The alternative is to delete line 9 of `R/multigrain-package.R` and regenerate `NAMESPACE`, relying on the generic in base; a throwaway package with `S3method(plot, foo)` and no import dispatched correctly in R 4.3.3, and this was not tried on R 4.1.

---

<a name="D_local_weights"></a>
## D_local_weights. The unused internal calc_local_weights() crashes for zero hypotheses and reads past a matrix that is too small

- Functions: none exported (internal calc_local_weights())
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** `calc_local_weights(w, G)` returns the weights of all intersection hypotheses; it is compiled into the package and called by nothing in `R/`, only by the tests and by one script under `dev/`. With three weights and a 2 x 2 matrix it returns a 7 x 6 matrix and no error. In the runs made here 6 of its 7 rows differed from the correct call, and the weights of the intersection of H1 and H2 came out as 0.6 and 0.3, which do not sum to 1. With zero hypotheses it ends the R session with a segmentation fault. No user reaches either today, but anyone who wires the function in later inherits both.

**What causes it.** `m` is taken from `w.size()` alone (`src/calc_local_weights.cpp:45`), and the matrix is then read with unchecked indexing such as `init_parent_G(del_index, h)` for positions up to `m` (`src/calc_local_weights.cpp:147-157`). For `m = 0` the number of intersections is `2^0 - 1 = 0`, so `graphs` is a vector of length 0 and `graphs[0] = initial_graph` writes outside it (`src/calc_local_weights.cpp:96-98`).

**Code showing the problem** ([`reprex/D_local_weights.R`](reprex/D_local_weights.R)):

```r
# D_local_weights: the internal calc_local_weights() crashes for zero hypotheses and reads past a small matrix
# Run: Rscript D_local_weights.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(0.5, 0.3, 0.2)
G <- rbind(c(0, 0.5, 0.5),
           c(0.5, 0, 0.5),
           c(0.5, 0.5, 0))
right <- multigrain:::calc_local_weights(w, G)
small <- tryCatch(multigrain:::calc_local_weights(w, G[1:2, 1:2]),      # 2 x 2 matrix, 3 weights
                  error = function(e) conditionMessage(e))
cat("3 weights with a 2 x 2 matrix:", if (is.matrix(small)) "no error" else small, "\n")
if (is.matrix(small)) {
    cat("rows that differ from the 3 x 3 call:", sum(rowSums(abs(small - right)) > 0), "of", nrow(right), "\n")
}

# Zero hypotheses end the R session, so the call is made in a child process.
code <- 'multigrain:::calc_local_weights(numeric(0), matrix(0, 0, 0))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with zero hypotheses: exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an R error from both calls\n")
```

Output on `gsd-build`:

```
3 weights with a 2 x 2 matrix: no error
rows that differ from the 3 x 3 call: 6 of 7
child process with zero hypotheses: exit status 139 (139 = segmentation fault)
EXPECTED: an R error from both calls
```

**Potential fix.** Guard the two inputs at the top of the function, as the kernels do:

```cpp
int m = w.size();
if (m < 1)
  stop("w must hold at least one hypothesis weight.");
if (G.nrow() != m || G.ncol() != m)
  stop("G must be an m x m matrix matching length(w).");
```

This is not in the fix series and has no test there; the script prints the same on both builds. It was tried only on a copy of the file compiled with `Rcpp::sourceCpp()`: both calls of the script then gave these errors, and the result for a valid graph of 3 hypotheses was identical to the package's. The alternative is to delete the function and its tests, since nothing in the package uses it.

---

<a name="D_plot_rounding"></a>
## D_plot_rounding. From 5 hypotheses up, plot() labels an edge of 0.001 as 0

- Functions: plot() and autoplot() of a result and of a graph constraint, print() of a result
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** With 5 to 8 hypotheses the plot rounds its labels to 2 decimals, and to 1 decimal above 8. The optimiser sets small edges to exactly 0.001 on purpose, and those are then drawn as arrows labelled 0. In the script an edge of 0.001 is labelled 0, an edge of 0.999 is labelled 1, and nodes with weights 0.004 and 0.996 read "w: 0" and "w: 1". A related slip in `print()`: it rounds to 4 decimals, so valid rows can look as if they sum to 1.0001 (seen for 2 of 6 rows of a 6-hypothesis result).

**What causes it.** `digits` defaults to 3 for up to 4 hypotheses, 2 for 5 to 8 and 1 above that (`R/plot_graph_optimal.R:52-58`, `R/plot_graph_constraint.R:58-64`), and `plot_graph()` labels with `round(.data$value, digits)` and `round(weight, digits)` (`R/plot_graph_optimal.R:130, 161`). Edges that are exactly 0 are not drawn (`create_edges()`, lines 243-245), so every arrow labelled 0 is a rounded non-zero value. The value 0.001 comes from `R/post_optim_processing.R:28`. `print()` rounds at `R/graph_optimal.R:199, 202`.

**Code showing the problem** ([`reprex/D_plot_rounding.R`](reprex/D_plot_rounding.R)):

```r
# D_plot_rounding: from 5 hypotheses up, plot() labels an edge of 0.001 as 0
# Run: Rscript D_plot_rounding.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 5 hypotheses. H1 has weight 0.004 and passes 0.001 to H2 (an epsilon edge) and 0.999 to H3.
tc <- rbind(c(0, 0.001, 0.999, 0, 0), c(NA, 0, NA, NA, NA), c(NA, NA, 0, NA, NA),
            c(NA, NA, NA, 0, NA), c(NA, NA, NA, NA, 0))
con <- graph_constraint(c(0.004, 0.996, 0, 0, 0), tc)

pdf(NULL)
layers <- ggplot2::ggplot_build(plot(con))$data    # layer 1: edges; layer 3: node labels
edges <- unique(layers[[1]][, c("from", "to", "label")])
nodes <- sub("\n", " ", layers[[3]]$label)

cat("label drawn on the edge H1 -> H2 (value 0.001):", edges$label[1], "\n")
cat("label drawn on the edge H1 -> H3 (value 0.999):", edges$label[2], "\n")
cat("labels drawn in the nodes H1 (0.004) and H2 (0.996):", nodes[1], "|", nodes[2], "\n")
cat("EXPECTED: labels that tell 0.001 from 0 and 0.999 from 1, for example <0.01 and >0.99\n")
```

Output on `gsd-build`:

```
label drawn on the edge H1 -> H2 (value 0.001): 0
label drawn on the edge H1 -> H3 (value 0.999): 1
labels drawn in the nodes H1 (0.004) and H2 (0.996): H1 w: 0 | H2 w: 1
EXPECTED: labels that tell 0.001 from 0 and 0.999 from 1, for example <0.01 and >0.99
```

**Potential fix.** Keep the rounding, but never write a value that is not 0 or 1 as "0" or "1". A helper for `plot_graph()`:

```r
label_value <- function(x, digits) {
    rounded <- round(x, digits)
    out <- as.character(rounded)
    step <- 10^-digits
    out[!is.na(x) & x > 0 & rounded == 0] <- paste0("<", step)
    out[!is.na(x) & x < 1 & rounded == 1] <- paste0(">", 1 - step)
    out
}

# in plot_graph():
#   label = label_value(.data$value, digits)            (edges)
#   "{name}\nw: {label_value(weight, digits)}"          (nodes)
```

This is a suggestion: it is not in the patch series and has no test. Tried once by patching `plot_graph()` in a loaded session, the script's labels became "<0.01", ">0.99", "w: <0.01" and "w: >0.99". Plot snapshot tests that contain such a value would change. For `print()`, a line saying that values are rounded to 4 decimals would be enough.

---

<a name="D_power_nominal"></a>
## D_power_nominal. The help calls power_nominal the power "at its final analysis"; it is the power at an information fraction of 1

- Functions: simulate_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 27)

**What the error is.** `?simulate_pvalues_gsd` describes `power_nominal` as the nominal power of each hypothesis "at its final analysis". That holds only when the last information fraction is 1. In the script the analyses are at fractions 0.5 and 0.8 with `power_nominal = 0.9`, and the simulated power at the final analysis is 0.825. A user whose design stops short of full information would size it on a power the simulator does not deliver, or would take the simulated power for a fault.

**What causes it.** The code follows its own model: the non-centrality parameter comes from `calc_ncp(power_nominal)`, and the mean of the statistic at an analysis is that parameter times the square root of the information fraction (`R/sim_pvals_gsd.R:127-128`). The nominal power is therefore reached at a fraction of 1. Only the roxygen is wrong: the `power_nominal` sentence (`R/sim_pvals_gsd.R:35-36`), "*final-look* statistics" in the description (lines 6-8) and "at the final analysis" for `corr_matrix` (lines 41-42).

**Code showing the problem** ([`reprex/D_power_nominal.R`](reprex/D_power_nominal.R)):

```r
# D_power_nominal: the help says "at its final analysis"; the code means "at full information"
# Run: Rscript D_power_nominal.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["simulate_pvalues_gsd.Rd"]]
help_txt <- capture.output(tools::Rd2txt(rd))
i <- grep("power_nominal: ", help_txt)
j <- i + which(help_txt[-seq_len(i)] == "")[1] - 1
cat("?simulate_pvalues_gsd says:", help_txt[i:j], sep = "\n")

set.seed(1)
x <- simulate_pvalues_gsd(0.9, info_frac = c(0.5, 0.8), nsim = 1e5)   # last analysis at 80%
cat("\nsimulated power at the final analysis:", mean(x[, 1, 2] < 0.025), "\n")
cat("power there from the code's model:    ", pnorm(calc_ncp(0.9) * sqrt(0.8) - qnorm(0.975)), "\n")
cat("EXPECTED: help that says 0.9 is the power at an information fraction of 1",
    "(0.83 at this final analysis)\n")
```

Output on `gsd-build`:

```
?simulate_pvalues_gsd says:
power_nominal: A numeric vector of nominal power values for each
          hypothesis, at its final analysis.

simulated power at the final analysis: 0.82511
power there from the code's model:     0.8262208
EXPECTED: help that says 0.9 is the power at an information fraction of 1 (0.83 at this final analysis)
```

**Potential fix.** Documentation only: say "full information" in the three places and regenerate the help page (done with the other pages in patch 61).

```diff
 #' @param power_nominal A numeric vector of nominal power values for each
-#'   hypothesis, at its final analysis.
+#'   hypothesis, each strictly between 0 and 1: the power of a single test at
+#'   level `alpha` with full information (an information fraction of 1). It is
+#'   the power at the final analysis only if that analysis is at an
+#'   information fraction of 1: with a last fraction of 0.8 and the default
+#'   `alpha`, a nominal 0.9 is 0.83 there.
```

With this change the script prints the new sentence; its two numbers stay the same, since no code changes. The alternative is to rescale so that `power_nominal` is reached at the last fraction, which would change the simulated p-values of every design that stops short of 1.

---

<a name="DOC1"></a>
## DOC1. The get-started article codes "both primaries" where its text and formula say "at least one"

- Functions: trial_success() (as used in the get-started article and in data-raw/)
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** The article describes its custom measure as success for rejecting at least one of the two primary hypotheses, with the formula `I(r1 + r2 >= 1)`. The code under it is `0.25 * (2 * (r1 && r2) + r1 * r3 + r2 * r4)`, which gives the primary credit only when both are rejected. A trial that rejects H1 and its secondary H3 scores 0.25 as coded and 0.75 as described. The graph and the table on the page belong to the coded measure. The two measures lead to different designs: in a reduced run on the article's scenario (100,000 trials, a shortened global search) the coded measure put 0.95 of the alpha on H1 and the described measure 0.725.

**What causes it.** `vignettes/articles/get-started.Rmd:264-271` (text and formula) and `:295` (code) disagree. The stored result that the page prints, `vignettes/articles/data/get-started-custom-power-graph.rds`, records the `&&` expression as its gain, and `data-raw/graph_optimal_example.R:43` uses the same expression for the bundled dataset. `README.Rmd:97` writes the measure with `||`. The article lines date from the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/DOC1.R`](reprex/DOC1.R)):

```r
# DOC1: the get-started article codes "both primaries" where its text says "at least one"
# Run from the repository root: Rscript DOC1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

art <- readLines("vignettes/articles/get-started.Rmd")
i <- grep("at least one of the$", art)
cat("article text :", trimws(art[i + 0:2]), "\n")
code <- trimws(grep("r1 && r2|r1 \\|\\| r2", art, value = TRUE))
cat("article code :", code, "\n")

as_coded <- eval(parse(text = sprintf("trial_success(%s, verbose = 'silent')", code)))
as_text <- trial_success(0.25 * (2 * (r1 || r2) + r1 * r3 + r2 * r4), verbose = "silent")

# One trial: the first primary H1 and its secondary H3 are rejected, H2 and H4 are not.
rej <- matrix(c(TRUE, FALSE, TRUE, FALSE), nrow = 1)
cat("score of that trial, measure as coded     :", as_coded$func(rej), "\n")
cat("score of that trial, measure as described :", as_text$func(rej), "\n")

g <- readRDS("vignettes/articles/data/get-started-custom-power-graph.rds")
cat("measure behind the results on the page    :", g$trial_success$objective, "\n")
cat("EXPECTED: text, formula, code and stored results use one measure (0.75 for this trial if it is 'at least one')\n")
```

Output on `gsd-build`:

```
article text : - Success for rejecting at least one of the two primary dose-control comparisons $H_1$ or $H_2$ (but no extra credit for rejecting both)
article code : 0.25 * (2 * (r1 && r2) + r1 * r3 + r2 * r4)
score of that trial, measure as coded     : 0.25
score of that trial, measure as described : 0.75
measure behind the results on the page    : 0.25 * (2 * (r1 && r2) + r1 * r3 + r2 * r4)
EXPECTED: text, formula, code and stored results use one measure (0.75 for this trial if it is 'at least one')
```

**Potential fix.** Decide which measure is meant. If it is "at least one", as in the README, change the operator and regenerate the article's stored result for the custom measure:

```diff
 custom_trial_success <- trial_success(
-    0.25 * (2 * (r1 && r2) + r1 * r3 + r2 * r4)
+    0.25 * (2 * (r1 || r2) + r1 * r3 + r2 * r4)
 )
```

This has not been implemented or tested: the stored graph, the figure and the table have to be recomputed with the article's 1,000,000 trials. The script then prints 0.75 on both score lines. The alternative is to keep the code and the results and change the text and the formula to "both primary comparisons", which needs no recomputation.

---

<a name="DOC2"></a>
## DOC2. The results printed in the get-started article are stored objects in an old layout

- Functions: graph_optimise(), graph_optimal_get_control() and summary() of an optimised graph (as shown in the get-started article)
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** The article does not run `graph_optimise()`. It reads two stored results and prints them. Both have the fields of an earlier version of the package: `opt_settings`, `nloptr_output` and `GA_output` where a current result has `control`, `local_output` and `global_output`, power fields named `LocalPower` and `PowAtlst1`, a gain of class `trial_success`, and the solution source `nlopt`. The page shows the code `summary(graph_average_power)` and under it the output of `print()`. On the stored object `summary()` prints an empty "Power metrics" section, no gain and no constraints, and `graph_optimal_get_control()` returns `NULL`. A reader who runs the article's code gets output that the page does not show.

**What causes it.** `vignettes/articles/get-started.Rmd:489-494` shows `summary()` in a chunk that is not evaluated. The hidden chunk at `:496-509` reads `data/get-started-avg-power-graph.rds` and `data/get-started-custom-power-graph.rds` and calls `print()`. Both files date from the first public commit `1c028a7`, and no script in the repository produces them, so nothing rebuilt them when the layout of the result changed. `summarise_power_object()` (`R/graph_optimal.R:104-152`) looks for `local_power`, `exp_rejections`, `disj_power` and `conj_power`, which the stored objects do not have.

**Code showing the problem** ([`reprex/DOC2.R`](reprex/DOC2.R)):

```r
# DOC2: the results shown in the get-started article are stored objects in an old layout
# Run from the repository root: Rscript DOC2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

old <- readRDS("vignettes/articles/data/get-started-avg-power-graph.rds")
cur <- graph_optimal_example   # an object in the layout graph_optimise() returns today

cat("fields, article object :", names(old), "\n")
cat("fields, current object :", names(cur), "\n")
cat("power,  article object :", names(old$power), "\n")
cat("power,  current object :", names(cur$power), "\n")
cat("class of the gain      :", class(old$trial_success), "(current:", class(cur$trial_success), ")\n")
cat("solution source        :", old$solution$opt_source, "(current:", cur$solution$opt_source, ")\n")
cat("graph_optimal_get_control() is NULL:", is.null(graph_optimal_get_control(old)), "\n\n")

# The article shows the code summary(graph_average_power). On the stored object it gives:
out <- capture.output(summary(old))
cat(out[grep("Power metrics", out):length(out)], sep = "\n")
cat("EXPECTED: the four power lines under 'Power metrics', the gain, the constraints and a control object,\n")
cat("          as summary(graph_optimal_example) and graph_optimal_get_control(graph_optimal_example) give\n")
```

Output on `gsd-build`:

```
fields, article object : hyp_weight trans_matrix constraints trial_success power opt_settings nloptr_output solution x0 global_opt_power local_opt_power GA_output
fields, current object : hyp_weight trans_matrix constraints trial_success power solution global_search control global_output local_output start_graph
power,  article object : LocalPower ExpRejections PowAtlst1 RejectAll trial_success
power,  current object : local_power exp_rejections disj_power conj_power trial_success
class of the gain      : trial_success (current: multigrain_trial_success )
solution source        : nlopt (current: local )
graph_optimal_get_control() is NULL: TRUE

Power metrics:

Solution source:
nlopt
EXPECTED: the four power lines under 'Power metrics', the gain, the constraints and a control object,
          as summary(graph_optimal_example) and graph_optimal_get_control(graph_optimal_example) give
```

**Potential fix.** Add a script that rebuilds both files from the article's inputs, rerun it before each release, and let the hidden chunk call `summary()` as the visible one does. For example `data-raw/get-started-results.R`:

```r
library(multigrain)
corr_matrix <- matrix(c(1, 0.5, 0.8, 0.4, 0.5, 1, 0.4, 0.8,
                        0.8, 0.4, 1, 0.5, 0.4, 0.8, 0.5, 1), nrow = 4)
set.seed(1)
pvals <- simulate_pvalues(c(0.97, 0.91, 0.86, 0.83), alpha = 0.025,
                          corr_matrix = corr_matrix, nsim = 1e6)
my_constraint <- graph_constraint(
    hyp_constraint = c(NA, NA, 0, 0),
    trans_constraint = matrix(c(0, NA, NA, 0, NA, 0, 0, NA,
                                0, 1, 0, 0, 1, 0, 0, 0), nrow = 4, byrow = TRUE)
)
gains <- list("avg-power" = trial_success(0.25 * (r1 + r2 + r3 + r4)),
              "custom-power" = trial_success(0.25 * (2 * (r1 || r2) + r1 * r3 + r2 * r4)))
for (name in names(gains)) {
    set.seed(2)
    res <- graph_optimise(pvals, my_constraint, alpha = 0.025, trial_success = gains[[name]])
    saveRDS(res, sprintf("vignettes/articles/data/get-started-%s-graph.rds", name))
}
```

This has not been implemented. The sketch was run once at reduced size (100,000 trials, a shortened global search, output to a temporary folder): `summary()` of its result prints the four power lines, the gain and the constraints, and `graph_optimal_get_control()` returns a control object. The second gain is written with `||`; see DOC1 for that decision.

---

<a name="DOC3"></a>
## DOC3. The pkgdown site does not build: four group sequential help topics are missing from the reference index

- Functions: calc_power_pvals_gsd(), graph_optimise_gsd(), graph_optimize_gsd(), simulate_pvalues_gsd(), transform_pvalues_gsd()
- Branches: gsd-build only
- Potential fix: tested (patch 62)

**What the error is.** Five of the six exported group sequential functions have no entry in the reference index of `_pkgdown.yml`. They make four help topics, since `graph_optimise_gsd()` and `graph_optimize_gsd()` share a page. pkgdown 2.0.7 refuses to build the reference index of this tree: "All topics must be included in reference index", with `calc_power_pvals_gsd`, `graph_optimise_gsd`, `simulate_pvalues_gsd` and `transform_pvalues_gsd` listed as missing. The workflow `.github/workflows/pkgdown.yaml` builds the site on every pull request and on every push to `main`, so the website cannot be built from this branch as it stands.

**What causes it.** `_pkgdown.yml:36-45` lists `trial_success_gsd` under "Inputs"; it was added there in `d9a3f8e`. The other group sequential functions were exported in `NAMESPACE` by other commits and were never added to a group. Once a `reference:` section exists, pkgdown requires every help topic that is not marked `@keywords internal` to appear in it. The design record plans the group (`dev/gsd_design_record.md:279`); it was not written.

**Code showing the problem** ([`reprex/DOC3.R`](reprex/DOC3.R)):

```r
# DOC3: four group sequential help topics are missing from the pkgdown reference index
# Run from the repository root: Rscript DOC3.R   (base R only)
# fmt: skip file
ns <- readLines("NAMESPACE")
exported <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))

yml <- readLines("_pkgdown.yml")
listed <- sub("^\\s*-\\s+", "", grep("^\\s+-\\s+[A-Za-z_.]+\\s*$", yml, value = TRUE))

# graph_optimise_gsd and graph_optimize_gsd share one help page, so five names are four topics
cat("exported functions:", length(exported), "\n")
cat("exported and not in the reference index of _pkgdown.yml:\n ",
    paste(setdiff(exported, listed), collapse = ", "), "\n")
cat("EXPECTED: none. pkgdown stops with 'All topics must be included in reference index'\n")
cat("          when a help topic that is not marked internal has no entry.\n")
```

Output on `gsd-build`:

```
exported functions: 24
exported and not in the reference index of _pkgdown.yml:
  calc_power_pvals_gsd, graph_optimise_gsd, graph_optimize_gsd, simulate_pvalues_gsd, transform_pvalues_gsd
EXPECTED: none. pkgdown stops with 'All topics must be included in reference index'
          when a help topic that is not marked internal has no entry.
```

**Potential fix.** Add the planned group and move `trial_success_gsd` into it:

```diff
     - simulate_pvalues
     - trial_success
-    - trial_success_gsd
     - graph_constraint
     - graph_constraint_free

+  - title: Group sequential designs
+    desc: >
+      Simulate, transform, optimise and evaluate with several analyses
+    contents:
+    - simulate_pvalues_gsd
+    - transform_pvalues_gsd
+    - trial_success_gsd
+    - graph_optimise_gsd
+    - graph_optimize_gsd
+    - calc_power_pvals_gsd
```

With this change the script lists no missing function, and pkgdown 2.0.7 accepts the reference index (checked with `pkgdown:::data_reference_index()` on a copy of the fixed tree). The rest of the site is unchanged. Where the group sits in the index, and whether `trial_success_gsd` stays under "Inputs" as well, is a matter of taste.

---

<a name="DOC4"></a>
## DOC4. A sentence of ?trial_success is cut off after "60"

- Functions: trial_success() (help page)
- Branches: gsd-build only
- Potential fix: tested (patches 31, 61)

**What the error is.** In the section "Interpreting the gain", the help source says that a gain over 4 hypotheses "each at 60% power returns approximately 2.4, not 0.6". The rendered page reads "hypotheses each at 60\ 0.6. This is m times average power." The numbers that explain the scale of the gain are lost, and the sentence that remains is wrong. It sits in the same help file as B8 and is cured by the same two patches, but its cause is different, so it has its own entry. It does not affect `R CMD check`.

**What causes it.** The roxygen comment at `R/trial_success.R:88` escapes the percent sign by hand: `60\%`. The package uses roxygen's markdown mode, which escapes again and writes `60\\%` to `man/trial_success.Rd:117`. In an Rd file `\\` is a literal backslash and the bare `%` that follows starts a comment, so the rest of that line is dropped. The line came in with `d9a3f8e`; `main` does not have it.

**Code showing the problem** ([`reprex/DOC4.R`](reprex/DOC4.R)):

```r
# DOC4: a sentence of ?trial_success is cut off after "60"
# Run from the repository root: Rscript DOC4.R   (reads man/ and R/; needs only base R)
# fmt: skip file
src <- readLines("R/trial_success.R", warn = FALSE)
rd <- readLines("man/trial_success.Rd", warn = FALSE)
cat("roxygen source:", grep("each at 60", src, value = TRUE), "\n")
cat("help file     :", grep("each at 60", rd, value = TRUE), "\n")

page <- capture.output(suppressWarnings(tools::Rd2txt("man/trial_success.Rd")))
cat("rendered help :", trimws(grep("each at 60", page, value = TRUE)), "\n")
cat("EXPECTED: ... hypotheses each at 60% power returns approximately 2.4, not 0.6.\n")
```

Output on `gsd-build`:

```
roxygen source: #' \eqn{m = 4} hypotheses each at 60\% power returns approximately 2.4, not
help file     : \eqn{m = 4} hypotheses each at 60\\% power returns approximately 2.4, not
rendered help : hypotheses each at 60\ 0.6. This is m times average power.
EXPECTED: ... hypotheses each at 60% power returns approximately 2.4, not 0.6.
```

**Potential fix.** Write the percent sign plainly and let roxygen escape it, then regenerate the help page. In `R/trial_success.R`:

```diff
-#' \eqn{m = 4} hypotheses each at 60\% power returns approximately 2.4, not
+#' \eqn{m = 4} hypotheses each at 60% power returns approximately 2.4, not
```

Run in the fixed tree, the script shows `60\%` in the help file and the rendered line "hypotheses each at 60% power returns approximately 2.4, not 0.6." The page is regenerated by the same patch that cures B8 (61), so the two can be taken together. No code changes.

---

<a name="DOC6"></a>
## DOC6. A roxygen-style link in the trial success article is shown as literal brackets

- Functions: trial_success() (article "Trial success measures")
- Branches: gsd-build only
- Potential fix: tested (patch 63)

**What the error is.** The trial success article introduces the injection operator with the text ``[`!!`][rlang::injection-operator]``. On the built page this is not a link. pandoc turns the line into `<p>[<code>!!</code>][rlang::injection-operator] operator:</p>`, so the reader sees the square brackets and the words `rlang::injection-operator` in the middle of the sentence and has nothing to click. The defect is cosmetic: the sentence still reads, and only the link is lost.

**What causes it.** `vignettes/articles/trial_success.qmd:82` uses the link form `[text][pkg::topic]`. roxygen2 resolves that form inside `#'` comments; Quarto and pandoc do not. In Markdown it is a reference link, which needs a definition line `[rlang::injection-operator]: <address>` somewhere in the file, and the file has none. The article was added on `gsd-build` in `d9a3f8e`, so `main` does not have it. The same commit added `vignettes/articles/trial_success.rmarkdown`, an older copy of the article that carries the same line.

**Code showing the problem** ([`reprex/DOC6.R`](reprex/DOC6.R)):

```r
# DOC6: a roxygen-style link in the trial success article is shown as literal text
# Run from the repository root: Rscript DOC6.R   (base R; uses pandoc when it is on the PATH)
# fmt: skip file
art <- readLines("vignettes/articles/trial_success.qmd")

# [text][pkg::topic] is a link only inside roxygen comments. In Markdown it is a
# reference link, which needs a line "[pkg::topic]: <address>" somewhere in the file.
i <- grep("\\]\\[[A-Za-z.]+::[^]]+\\]", art)
cat("roxygen-style links in the article:", length(i), "\n")
if (length(i)) cat(sprintf("  line %d: %s\n", i, art[i]), sep = "")
cat("reference definitions in the article:", sum(grepl("^\\[[^]]+\\]:\\s", art)), "\n")

if (length(i) && nzchar(Sys.which("pandoc"))) {
    html <- system2("pandoc", c("-f", "markdown", "-t", "html"), input = art[i], stdout = TRUE)
    cat("pandoc turns the line into:", html, "\n")
}
cat("EXPECTED: no such link; a Markdown link to the rlang page is rendered as <a href=...>\n")
```

Output on `gsd-build`:

```
roxygen-style links in the article: 1
  line 82: [`!!`][rlang::injection-operator] operator:
reference definitions in the article: 0
pandoc turns the line into: <p>[<code>!!</code>][rlang::injection-operator] operator:</p>
EXPECTED: no such link; a Markdown link to the rlang page is rendered as <a href=...>
```

**Potential fix.** Write an ordinary Markdown link to the rlang reference page:

```diff
 To inject values from your R session into the expression, use rlang's
-[`!!`][rlang::injection-operator] operator:
+[`!!`](https://rlang.r-lib.org/reference/injection-operator.html) operator:
```

With this change the script finds no roxygen-style link in the article, and pandoc renders the line as `<a href="https://rlang.r-lib.org/reference/injection-operator.html"><code>!!</code></a>`. The patch does not touch `trial_success.rmarkdown`. That file looks like a Quarto intermediate committed by mistake; deleting it and adding `*.rmarkdown` to `.gitignore` is the better course, and is not part of the tested series.

---

<a name="DOC7"></a>
## DOC7. NEWS.md announces neither the group sequential functions nor the new gsDesign dependency

- Functions: simulate_pvalues_gsd(), transform_pvalues_gsd(), trial_success_gsd(), graph_optimise_gsd(), graph_optimize_gsd(), calc_power_pvals_gsd()
- Branches: gsd-build only
- Potential fix: tested (patches 64, 71)

**What the error is.** The branch adds six exported functions and a new hard dependency, gsDesign. The development section of `NEWS.md` has one heading, "Bug fixes", with one entry. That entry names `trial_success_gsd()` only as the source of the gain that is refused, and `graph_optimise_gsd()` and `calc_power_pvals_gsd()` only as the functions to use in place of the fixed-sample ones. `simulate_pvalues_gsd()`, `transform_pvalues_gsd()` and `graph_optimize_gsd()` are not mentioned at all, and neither is gsDesign. A user who updates and reads the news learns of a refusal and not of the feature behind it, and is not told that a new package will be installed.

**What causes it.** The only change to `NEWS.md` on the branch is the bug-fix entry added in `9a88c24` (`NEWS.md:3-8`). The design record holds the wording for the announcement (`dev/gsd_design_record.md:315-334`) and lists it as a task of its documentation phase (`:279`); it was never copied into the file.

**Code showing the problem** ([`reprex/DOC7.R`](reprex/DOC7.R)):

```r
# DOC7: NEWS.md does not announce the group sequential functions or the gsDesign dependency
# Run from the repository root: Rscript DOC7.R   (base R only)
# fmt: skip file
news <- readLines("NEWS.md")
dev <- news[seq_len(grep("^# multigrain [0-9]", news)[1] - 1)]   # the development section
cat("headings in the development section:", grep("^## ", dev, value = TRUE), "\n")

ns <- readLines("NAMESPACE")
gsd <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(.*_gsd\\)$", ns, value = TRUE))
for (f in gsd) {
    cat(sprintf("%-24s mentioned in the development section: %s\n", f,
                any(grepl(paste0(f, "()"), dev, fixed = TRUE))))
}
cat("gsDesign in Imports of DESCRIPTION      :",
    grepl("gsDesign", read.dcf("DESCRIPTION", "Imports")), "\n")
cat("gsDesign mentioned in the development section:", any(grepl("gsDesign", dev)), "\n")
cat("EXPECTED: a 'New functionality' heading that names all six functions and the new dependency\n")
```

Output on `gsd-build`:

```
headings in the development section: ## Bug fixes
calc_power_pvals_gsd     mentioned in the development section: TRUE
graph_optimise_gsd       mentioned in the development section: TRUE
graph_optimize_gsd       mentioned in the development section: FALSE
simulate_pvalues_gsd     mentioned in the development section: FALSE
transform_pvalues_gsd    mentioned in the development section: FALSE
trial_success_gsd        mentioned in the development section: TRUE
gsDesign in Imports of DESCRIPTION      : TRUE
gsDesign mentioned in the development section: FALSE
EXPECTED: a 'New functionality' heading that names all six functions and the new dependency
```

**Potential fix.** Add a "New functionality" heading above "Bug fixes", with the wording of the design record and the alias `graph_optimize_gsd()` added:

```diff
 # multigrain (development version)

+## New functionality
+
+* Group sequential designs are supported through a new family of functions.
+  `simulate_pvalues_gsd()` simulates p-values at several analyses under the
+  canonical joint normal model; `transform_pvalues_gsd()` converts them to
+  repeated (or, per hypothesis, sequential) p-values using alpha-spending
+  boundaries computed with gsDesign; `trial_success_gsd()` defines a gain
+  function of rejections and decision times; `graph_optimise_gsd()` (alias
+  `graph_optimize_gsd()`) optimises a graph for a group sequential design;
+  `calc_power_pvals_gsd()` reports power by hypothesis and by analysis. The
+  fixed-sample functions are unchanged.
+* New dependency: gsDesign (Imports). graphicalMCP (>= 0.3.0) is used in the
+  test suite only (Suggests).
+
 ## Bug fixes
```

With this change the script prints `TRUE` for all six functions and for gsDesign. The block above is shortened; the tested patches also add one entry for each group of fixes in the series, which matter only if those fixes are taken.

---

<a name="DOC8"></a>
## DOC8. The script in data-raw no longer rebuilds the bundled dataset

- Functions: graph_optimal_example (dataset), graph_optimise()
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** `data-raw/graph_optimal_example.R` fixes its seeds, so running it should return the dataset the package ships. It does not. The bundled graph has gain 0.6393278, source `local`, and transition weights 0.8987 (H1 to H2) and 0.7679 (H2 to H1). The script run on `gsd-build` gives gain 0.6385696, source `global`, and weights 0.7702 and 0.6068, with one thread or with two. The hypothesis weights agree. Two snapshot tests print the dataset (`tests/testthat/test-graph_optimal.R:175-176`), so whoever next reruns the script changes those snapshots too.

**What causes it.** The dataset and the script both date from the first public commit `1c028a7`. Commit `e62dfcf` later changed which rows the two search stages draw (`.sample_pvals_rows()`, `R/optimisation.R:269`), so the same seeds now select other rows. A build of the tag `v0.3.0`, whose code is that of the first commit, gives a third graph (gain 0.639473). The dataset therefore also depends on something the script does not record: the stored object reports NLopt 2.10.1, and the runs here used NLopt 2.7.1. The script also calls `cran_cores()` (`data-raw/graph_optimal_example.R:50`), a helper from `tests/testthat/helper-cran_cores.R`, so it runs only under `devtools::load_all()`.

**Code showing the problem** ([`reprex/DOC8.R`](reprex/DOC8.R)):

```r
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
```

Output on `gsd-build`:

```
✔ Trial success function compiled and sourced successfully.
bundled dataset: gain 0.6393278  source local   H1->H2 0.8987  H2->H1 0.7679
script output  : gain 0.6385696  source global  H1->H2 0.7702  H2->H1 0.6068
same transition matrix: FALSE
EXPECTED: TRUE, and the same gain and source, since the script fixes every seed
```

**Potential fix.** Rerun the script once on the code to be released and commit the dataset together with the snapshots it changes. Make the script self-contained and let it record what it was built with:

```diff
+library(multigrain)
+# Last built with multigrain 0.3.0.9000, GA 3.2.5, nloptr 2.0.3 (NLopt 2.7.1).
+# After a rebuild, run testthat::snapshot_accept("graph_optimal").
 ctrl <- multigrain_control() |>
     control_global(run = 7) |>
     control_nsim_local(2e4)
@@
     control = ctrl,
-    num_threads = cran_cores(),
+    num_threads = 2,
     global_search = TRUE,
```

This has not been implemented or tested. After it the script should print the same gain and source on both lines and `TRUE`, on the machine that rebuilt the dataset. The versions in the comment are placeholders. The alternative is to leave the dataset alone and say in the script that it no longer reproduces it.

---

<a name="DOC9"></a>
## DOC9. A development vignette documents optimize_N(), which was removed, and its data file sits with the published articles

- Functions: none exported (optimise_N() and optimize_N() were removed in version 0.2.0)
- Branches: main and gsd-build
- Potential fix: suggested, not implemented

**What the error is.** `dev/vignettes/opt-sample-size.Rmd` is a complete vignette on sample size optimisation with `optimize_N()`: seven of its lines name the function. The package has no such function, and `NEWS.md` records its removal. The vignette could not be built even if the function came back, since it reads `./data/optN_result.rds` and there is no `data` folder next to it. The file it wants is `vignettes/articles/data/optN_result.rds`, in the folder of the published articles, where none of the three articles uses it. That object has class `graph_optimal`, which no method of the current package handles, so printing it gives 1,322 lines of raw list. Nothing here reaches a user of the installed package; the risk is to a contributor who takes the vignette for current documentation.

**What causes it.** The sample size functionality was removed in version 0.2.0 (`NEWS.md:77`). Its source and tests are parked in `dev/` (`dev/sample_size_optimization.R`, `dev/test-sample_size_optimization.R`), and the vignette sits there with them. Its stored result is in `vignettes/articles/data/`, which the `readRDS()` path in the vignette (line 289) does not reach. The repository has been in this state since the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/DOC9.R`](reprex/DOC9.R)):

```r
# DOC9: a development vignette documents optimize_N(), which the package no longer has
# Run from the repository root: Rscript DOC9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

v <- readLines("dev/vignettes/opt-sample-size.Rmd")
cat("lines of dev/vignettes/opt-sample-size.Rmd that mention optimize_N:",
    sum(grepl("optimize_N", v)), "\n")
cat("optimize_N or optimise_N in the package:",
    any(c("optimize_N", "optimise_N") %in% ls(asNamespace("multigrain"))), "\n")
cat("NEWS.md:", grep("optimise_N()`) has been removed", readLines("NEWS.md"), fixed = TRUE, value = TRUE), "\n")

cat("the vignette reads:", trimws(grep("readRDS", v, value = TRUE)),
    "; file present next to it:", file.exists("dev/vignettes/data/optN_result.rds"), "\n")
arts <- list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$", full.names = TRUE)
cat("published articles that use vignettes/articles/data/optN_result.rds:",
    sum(grepl("optN_result", unlist(lapply(arts, readLines)))), "\n")
x <- readRDS("vignettes/articles/data/optN_result.rds")
cat("class of that stored object:", class(x), "; lines printed by print():", length(capture.output(print(x))), "\n")
cat("EXPECTED: no vignette and no data file for a removed function, or a vignette that runs\n")
```

Output on `gsd-build`:

```
lines of dev/vignettes/opt-sample-size.Rmd that mention optimize_N: 7
optimize_N or optimise_N in the package: FALSE
NEWS.md: * The sample size optimisation functionality (`optimise_N()`) has been removed.
the vignette reads: optN_result <- readRDS("./data/optN_result.rds") ; file present next to it: FALSE
published articles that use vignettes/articles/data/optN_result.rds: 0
class of that stored object: graph_optimal ; lines printed by print(): 1322
EXPECTED: no vignette and no data file for a removed function, or a vignette that runs
```

**Potential fix.** Keep the parked material together and say what it is. Move the data file next to the vignette, and open the vignette with a note:

```diff
+> Parked: `optimise_N()` was removed from multigrain in version 0.2.0. This
+> vignette describes the code kept in `dev/sample_size_optimization.R` and does
+> not run against the current package.
+
 ## Why sample size optimisation?
```

together with `mkdir dev/vignettes/data` and `git mv vignettes/articles/data/optN_result.rds dev/vignettes/data/optN_result.rds`. This has not been implemented or tested. After it the script reports the file as present next to the vignette, and its last two lines need the new path. The alternative is to delete the vignette and the data file until the feature returns.

---

<a name="DOC10"></a>
## DOC10. The help example of calc_power_pvals() calls a sum of rejections "average_power"

- Functions: calc_power_pvals() (help page)
- Branches: main and gsd-build
- Potential fix: tested (patch 15)

**What the error is.** The example in `?calc_power_pvals` defines a custom measure `average_power = function(x) { x[1] + x[2] + x[3] }`. That is the number of hypotheses rejected in one trial, so the value reported is the expected number of rejections. Run with `set.seed(1)`, the example gives `average_power` 2.289, identical to `exp_rejections`, where the mean of the three local powers is 0.763. A user who copies the example reports an "average power" above 1.

**What causes it.** The roxygen example at `R/calc_power.R:98-100`, and the same lines in `man/calc_power_pvals.Rd`. A custom function receives the logical vector of one trial and its results are averaged over the trials (`R/calc_power.R:250-256`). A sum over the hypotheses is therefore not divided by their number.

**Code showing the problem** ([`reprex/DOC10.R`](reprex/DOC10.R)):

```r
# DOC10: the help example of calc_power_pvals() calls a sum of rejections "average_power"
# Run: Rscript DOC10.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
example(calc_power_pvals, echo = FALSE)    # runs the help example; leaves `result`

cat("average_power in the help example:", result$average_power, "\n")
cat("expected number of rejections:    ", result$exp_rejections, "\n")
cat("mean of the three local powers:   ", mean(result$local_power), "\n")
cat("EXPECTED: average_power equal to the mean of the local powers, a number between 0 and 1\n")
```

Output on `gsd-build`:

```
✔ Trial success function compiled and sourced successfully.
average_power in the help example: 2.28894
expected number of rejections:     2.28894
mean of the three local powers:    0.76298
EXPECTED: average_power equal to the mean of the local powers, a number between 0 and 1
```

**Potential fix.** Make the example a mean and regenerate the help page (done with the other pages in patch 61):

```diff
 #'   average_power = function(x) {
-#'     x[1] + x[2] + x[3]
+#'     mean(x)
 #'   }
```

With this change the script prints 0.763 for `average_power`, equal to the mean of the local powers. No code changes. The alternative is to keep the sum and rename the measure, which would then duplicate `exp_rejections`.

---

<a name="DOC11"></a>
## DOC11. The help text of sum_to_one_constraint reads as the opposite of what the argument does

- Functions: is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() (help pages)
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 16)

**What the error is.** The three help pages describe the argument as controlling "whether to allow graphs where transition matrix rows are not constrained to sum to one, for example in a fixed sequence. Defaults to `TRUE`". Read literally, `TRUE` allows such graphs. It is the other way round: with `TRUE`, the default, a fixed sequence is refused, and `FALSE` is the setting that accepts it, as the script shows. The same pages say without qualification that each row of `trans_matrix` "must sum to 1", and the page of `is_graph_valid()` carries a stray "both". A user with a terminal node has to find the right setting by trial and error.

**What causes it.** The roxygen text at `R/utils.R:84-86`, `R/calc_power.R:42-44` and `R/calc_power_gsd.R:37-39`. The unqualified statements about the rows are at `R/utils.R:81-83` and `R/utils.R:105`. The code itself does what the name says: the row sums are required to equal 1 inside `if (sum_to_one_constraint)` (`R/utils.R:189-198`).

**Code showing the problem** ([`reprex/DOC11.R`](reprex/DOC11.R)):

```r
# DOC11: the help text of sum_to_one_constraint reads as the opposite of what the argument does
# Run: Rscript DOC11.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["is_graph_valid.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("^sum_to_one_constraint:", txt)
cat("?is_graph_valid says:", txt[i:(i + 3)], sep = "\n")

w <- c(1, 0, 0)                              # fixed sequence H1 -> H2 -> H3
G <- rbind(c(0, 1, 0),
           c(0, 0, 1),
           c(0, 0, 0))                       # the last row sums to 0
cat("fixed sequence, sum_to_one_constraint = TRUE (the default):",
    suppressWarnings(is_graph_valid(w, G, sum_to_one_constraint = TRUE)), "\n")
cat("fixed sequence, sum_to_one_constraint = FALSE:             ",
    is_graph_valid(w, G, sum_to_one_constraint = FALSE), "\n")
cat("EXPECTED: text saying that TRUE requires every row to sum to 1 and FALSE allows less\n")
```

Output on `gsd-build`:

```
?is_graph_valid says:
sum_to_one_constraint: A logical indicating whether to allow graphs
          where both the transition matrix rows are not constrained to
          sum-to-one, for example in a fixed sequence. Defaults to
          ‘TRUE’.
fixed sequence, sum_to_one_constraint = TRUE (the default): FALSE
fixed sequence, sum_to_one_constraint = FALSE:              TRUE
EXPECTED: text saying that TRUE requires every row to sum to 1 and FALSE allows less
```

**Potential fix.** Say what each value does. In `R/utils.R`, and with the same wording in the other two files:

```diff
-#' @param sum_to_one_constraint A logical indicating whether to allow graphs
-#'   where both the transition matrix rows are not constrained to sum-to-one,
-#'   for example in a fixed sequence. Defaults to `TRUE`.
+#' @param sum_to_one_constraint A single logical value. If `TRUE` (the
+#'   default), every row of `trans_matrix` must sum to 1. Set to `FALSE` to
+#'   allow rows that sum to less than 1, for example the last row of a fixed
+#'   sequence.
```

The patch also adds "(to at most 1 when `sum_to_one_constraint = FALSE`)" to `@param trans_matrix`. With this change and the help pages regenerated (done with the other pages in patch 61) the script prints the new text; the two results below it are the same on both builds. No code changes. The words "less than 1" are true only together with the fix of A4: on the unfixed build `FALSE` accepts any row sum.

---

<a name="DOC13"></a>
## DOC13. Nothing a user reads says that defining a gain needs a C++ toolchain every time

- Functions: trial_success(), trial_success_gsd()
- Branches: main and gsd-build (trial_success_gsd() on gsd-build only)
- Potential fix: tested (patch 45)

**What the error is.** Both constructors compile C++ when they are called, not only when the package is installed (round 2 DOC13 and ENV07, the same finding from the documentation side and from the session side). A user who installed a binary package on a machine without Rtools, Xcode or a compiler can simulate p-values and compute power, and then cannot define any gain. With `make` made unfindable, `trial_success(r1 + r2)` stopped here with "Error 1 occurred building shared library", after Rcpp's own warning that the build tools were not found. The README and the help of both constructors do not mention the requirement, and `DESCRIPTION` lists only "GNU make".

**What causes it.** `Rcpp::sourceCpp()` is called at run time (`R/trial_success.R:314`, `R/trial_success_gsd.R:713`). That is the design; only the statement of the requirement is missing.

**Code showing the problem** ([`reprex/DOC13.R`](reprex/DOC13.R)):

```r
# DOC13: nothing a user reads says that defining a gain needs a C++ toolchain every time
# Run from the repository root: Rscript DOC13.R   (reads the sources; needs only base R)
# fmt: skip file

# Where the package compiles C++ when a user calls it, not when it is installed
for (f in c("R/trial_success.R", "R/trial_success_gsd.R")) {
    cat(sprintf("%s: sourceCpp() called at line %s\n", f,
                paste(grep("^ *sourceCpp\\(", readLines(f, warn = FALSE)), collapse = ", ")))
}

# What the documentation says about it
cat("DESCRIPTION, SystemRequirements:", read.dcf("DESCRIPTION", "SystemRequirements"), "\n")
for (f in c("README.md", "man/trial_success.Rd", "man/trial_success_gsd.Rd")) {
    hits <- grep("toolchain|compiler|Rtools|Xcode", readLines(f, warn = FALSE), ignore.case = TRUE)
    cat(sprintf("%-25s lines that mention a compiler or a toolchain: %d\n", f, length(hits)))
}
cat("EXPECTED: the requirement stated in the help of both constructors\n")
```

Output on `gsd-build`:

```
R/trial_success.R: sourceCpp() called at line 314
R/trial_success_gsd.R: sourceCpp() called at line 713
DESCRIPTION, SystemRequirements: GNU make
README.md                 lines that mention a compiler or a toolchain: 0
man/trial_success.Rd      lines that mention a compiler or a toolchain: 0
man/trial_success_gsd.Rd  lines that mention a compiler or a toolchain: 0
EXPECTED: the requirement stated in the help of both constructors
```

**Potential fix.** Say it in the details of both help pages. In `R/trial_success.R`, and the same paragraph in `R/trial_success_gsd.R`:

```r
#' The compilation happens when `trial_success()` is called, so a C++
#' toolchain (Rtools on Windows, the Xcode command line tools on macOS, a C++
#' compiler and `make` on Linux) is needed at run time, every time a gain is
#' defined, and not only when the package is installed.
```

Run in the fixed tree, the script finds the requirement in `man/trial_success.Rd` and `man/trial_success_gsd.Rd` (regenerated with the other pages in patch 61). The tested patch stops there: the README and `DESCRIPTION` still do not mention it, and the error without a toolchain is still Rcpp's. Suggested and not implemented: the same sentence in the README and a mention in `SystemRequirements`.

---

<a name="DOC15"></a>
## DOC15. The get-started article has a dead link to the graph constraint article and a chunk with two labels

- Functions: graph_constraint() (get-started article)
- Branches: main and gsd-build
- Potential fix: tested (patch 63)

**What the error is.** The sentence "Please see the dedicated vignette on this topic" in the get-started article links to `articles/graph_constraint.html`. The article itself is published as `articles/get-started.html`, so the browser resolves the link to `articles/articles/graph_constraint.html`, a page that does not exist. The two other links between articles in the same file are written correctly, as `trial_success.html` and `graph_constraint.html`. Second face: the chunk that draws the two optimised graphs has the header `{r plot, my-plot, ...}`. knitr 1.45 reads this as one label, `plot, my-plot`, and names the figure file `plot, my-plot-1.png`, with a comma and a space in the file name.

**What causes it.** `vignettes/articles/get-started.Rmd:357` writes the link relative to the site root. The page is published under `articles/`, so a relative link is resolved from that folder, as line 610 of the same file assumes. `vignettes/articles/get-started.Rmd:513` gives the chunk two labels, which knitr reads as a single label with a comma in it. Both lines date from the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/DOC15.R`](reprex/DOC15.R)):

````r
# DOC15: the get-started article has a dead relative link and a chunk with two labels
# Run from the repository root: Rscript DOC15.R   (base R only)
# fmt: skip file
art <- readLines("vignettes/articles/get-started.Rmd")

# pkgdown writes every file of vignettes/articles/ to articles/<name>.html, so a
# relative link in an article is resolved from articles/.
built <- sub("\\.(Rmd|qmd)$", ".html", list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$"))
i <- grep("\\]\\([A-Za-z_/-]+\\.html\\)", art)
target <- sub(".*\\]\\(([A-Za-z_/-]+\\.html)\\).*", "\\1", art[i])
cat(sprintf("line %d links to %-30s page exists: %s\n", i, target, target %in% built), sep = "")

# A chunk header takes one label; knitr reads "a, b" before the first option as one label.
cat("chunk headers with two labels:", grep("^```\\{r [A-Za-z_-]+, [A-Za-z_-]+,", art, value = TRUE), "\n")
cat("EXPECTED: every link resolves, and no chunk header has two labels\n")
````

Output on `gsd-build`:

````
line 231 links to trial_success.html             page exists: TRUE
line 357 links to articles/graph_constraint.html page exists: FALSE
line 610 links to graph_constraint.html          page exists: TRUE
chunk headers with two labels: ```{r plot, my-plot, fig.width=8, fig.height=4.5, out.width='100%'}
EXPECTED: every link resolves, and no chunk header has two labels
````

**Potential fix.** Drop the folder from the link and keep one label:

```diff
-Please see the [dedicated vignette](articles/graph_constraint.html) on this topic for more details about setting and plotting graph constraints.
+Please see the [dedicated vignette](graph_constraint.html) on this topic for more details about setting and plotting graph constraints.
@@ chunk header at line 513, shown without its three backticks
-{r plot, my-plot, fig.width=8, fig.height=4.5, out.width='100%'}
+{r my-plot, fig.width=8, fig.height=4.5, out.width='100%'}
```

With this change the script reports that all three links resolve and finds no chunk header with two labels. Nothing else in the article changes; the figure file becomes `my-plot-1.png`.

---

<a name="DOC16"></a>
## DOC16. Package metadata is out of step: two unused website dependencies, a release version under a development heading, an incomplete word list

- Functions: none (DESCRIPTION, NEWS.md, inst/WORDLIST)
- Branches: main and gsd-build (the website dependencies; since ed9a559 of 6 October 2026 the version and most of the word list on gsd-build only)
- Potential fix: suggested, not implemented

**What the error is.** Three small things in the package metadata do not match the code. First, `Config/Needs/website` asks every site build to install gMCP and graphicalMCP, and no article, README or help example calls either of them. Second, `DESCRIPTION` says version 0.3.0 while `NEWS.md` opens with "multigrain (development version)", so the development code carries the number of the release (REG3 gives the consequence); `main` has carried a development version since `ed9a559` of 6 October 2026. Third, `spelling::spell_check_package()`, which the script does not run, reports 16 words that are not in `inst/WORDLIST`, among them `arXiv`, `Grayling`, `Mander`, `GSD` and `argmax`. None of this affects a result.

**What causes it.** `DESCRIPTION:49` lists the four website packages; only rmarkdown and gridExtra are used (`vignettes/articles/get-started.Rmd:3, 534`). The line dates from the first public commit `1c028a7`. The word list on this branch was last updated in `324b7ca`, before the group sequential help pages and the arXiv reference were written; `main` has since added `Grayling` and `Mander` (`ed9a559`, `036ab2b`). `tests/spelling.R` runs the check with `error = FALSE`, so new words never fail a test.

**Code showing the problem** ([`reprex/DOC16.R`](reprex/DOC16.R)):

```r
# DOC16: the website dependencies list two unused packages; version and word list are out of step
# Run from the repository root: Rscript DOC16.R   (base R only)
# fmt: skip file
d <- read.dcf("DESCRIPTION")
needs <- trimws(strsplit(d[, "Config/Needs/website"], ",")[[1]])
cat("Config/Needs/website:", paste(needs, collapse = ", "), "\n")

# What the site builds: the articles, the README and the examples of the help pages.
files <- c(list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$", full.names = TRUE),
           "README.Rmd", list.files("man", pattern = "\\.Rd$", full.names = TRUE))
text <- unlist(lapply(files, readLines, warn = FALSE))
for (p in needs) {
    used <- sum(grepl(paste0("\\b", p, "::|library\\(", p, "\\)"), text))
    cat(sprintf("  %-13s lines that call it (pkg:: or library()): %d\n", p, used))
}
cat("Version:", d[, "Version"], "  first heading of NEWS.md:", readLines("NEWS.md", n = 1), "\n")
cat("EXPECTED: only packages the site uses, and a development version number under a development heading\n")
```

Output on `gsd-build`:

```
Config/Needs/website: rmarkdown, gMCP, graphicalMCP, gridExtra
  rmarkdown     lines that call it (pkg:: or library()): 1
  gMCP          lines that call it (pkg:: or library()): 0
  graphicalMCP  lines that call it (pkg:: or library()): 0
  gridExtra     lines that call it (pkg:: or library()): 1
Version: 0.3.0   first heading of NEWS.md: # multigrain (development version)
EXPECTED: only packages the site uses, and a development version number under a development heading
```

**Potential fix.** Trim the website dependencies and add the missing words. In `DESCRIPTION`:

```diff
-Config/Needs/website: rmarkdown, gMCP, graphicalMCP, gridExtra
+Config/Needs/website: rmarkdown, gridExtra
```

and run `spelling::update_wordlist()` after reading the list it proposes. This has not been implemented or tested; in particular the site has not been built without the two packages. After the change the script lists two website packages, each with one use. The version number arrives with a merge of `main` and is covered under REG3. If the two packages are listed for an article that is still planned, they can return with that article.

---

<a name="DOC17a"></a>
## DOC17a. The result name of a single custom_power measure is not documented

- Functions: calc_power_pvals(), calc_power_pvals_gsd() (help pages)
- Branches: main and gsd-build (calc_power_pvals_gsd() on gsd-build only)
- Potential fix: tested (patch 17)

**What the error is.** `custom_power` may be a single function or a single gain, given without a list. Its value then comes back as `out$custom_power`. The help says that a single measure can be given, and that unnamed entries of a list are called `func1`, `func2` and so on; it does not say what a single measure is called. A user has to print `names(out)` to find the value. `calc_power_pvals_gsd()` behaves the same and its help has the same gap.

**What causes it.** The name is set where the argument is normalised: `return(list(custom_power = x))` in `.auto_name_custom_power()` (`R/calc_power.R:196-198`) and in `.auto_name_custom_power_gsd()` (`R/calc_power_gsd.R:259-261`). The `@param custom_power` text does not mention it (`R/calc_power.R:20-22`, `R/calc_power_gsd.R:22-24`).

**Code showing the problem** ([`reprex/DOC17a.R`](reprex/DOC17a.R)):

```r
# DOC17a: the result name of a single custom_power measure is not documented
# Run: Rscript DOC17a.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

set.seed(1)
pvals <- simulate_pvalues(c(0.9, 0.8), nsim = 500)
out <- calc_power_pvals(pvals, c(0.5, 0.5), matrix(c(0, 1, 1, 0), 2),
                        custom_power = function(x) x[1] && x[2])
cat("names of the result:", names(out), "\n")

rd <- tools::Rd_db("multigrain")[["calc_power_pvals.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("^custom_power:", txt)
cat("?calc_power_pvals on a single measure:", txt[i:(i + 3)], sep = "\n")
cat("EXPECTED: the help says that a single measure is reported as `custom_power`\n")
```

Output on `gsd-build`:

```
names of the result: local_power exp_rejections disj_power conj_power custom_power
?calc_power_pvals on a single measure:
custom_power: A list of user-defined power functions. Alternatively, a
          single function or ‘multigrain_trial_success’ object can be
          provided. There are two ways to specify this:

EXPECTED: the help says that a single measure is reported as `custom_power`
```

**Potential fix.** Add the sentence to the help of both functions. In `R/calc_power.R`:

```diff
 #' @param custom_power A list of user-defined power functions. Alternatively, a
-#'   single function or `multigrain_trial_success` object can be provided.
-#'   There are two ways to specify this:
+#'   single function or `multigrain_trial_success` object can be provided
+#'   without a list; its value is then reported under the name
+#'   `"custom_power"`. There are two ways to specify this:
```

With this change and the help page regenerated (done with the other pages in patch 61) the script prints the new help text; the names of the result are unchanged. No code changes. The alternative is to name a single measure `func1`, as an unnamed list entry would be, which changes the result for existing code.

---

<a name="DOC17h"></a>
## DOC17h. The graph constraint article calls the argument for the number of hypotheses `m`; it is `num_hyp`

- Functions: graph_constraint_free()
- Branches: main and gsd-build
- Potential fix: tested (patch 63)

**What the error is.** The graph constraint article lists three ways to build a constraint. The third reads "by supplying the number of hypotheses (`m`)". No constructor has an argument `m`. The function that takes a number of hypotheses is `graph_constraint_free()`, and its argument is `num_hyp`: `graph_constraint_free(m = 3)` stops with "unused argument (m = 3)". A reader who follows the list literally gets that error; the section further down the article, which calls `graph_constraint_free(5)` by position, works.

**What causes it.** `vignettes/articles/graph_constraint.qmd:54` uses the mathematical symbol for the number of hypotheses where the code formatting promises an argument name. The arguments of `graph_constraint_free()` are `num_hyp` and `names`; those of `graph_constraint()` are `hyp_constraint`, `trans_constraint`, `...`, `names`, `diagnose` and `tolerance`. The line dates from the first public commit `1c028a7`.

**Code showing the problem** ([`reprex/DOC17h.R`](reprex/DOC17h.R)):

```r
# DOC17h: the graph constraint article calls the argument `m`; it is `num_hyp`
# Run from the repository root: Rscript DOC17h.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

art <- readLines("vignettes/articles/graph_constraint.qmd")
i <- grep("by supplying the number of hypotheses", art)
cat(sprintf("article, line %d: %s\n", i, sub("\\. In this case.*", ".", art[i])))
cat("arguments of graph_constraint_free():", names(formals(graph_constraint_free)), "\n")

msg <- tryCatch({ graph_constraint_free(m = 3); "no error" }, error = function(e) conditionMessage(e))
cat("graph_constraint_free(m = 3):", msg, "\n")
cat("graph_constraint_free(num_hyp = 3): a constraint on",
    length(graph_constraint_free(num_hyp = 3)$hyp_constraint), "hypotheses\n")
cat("EXPECTED: the article names the argument `num_hyp`\n")
```

Output on `gsd-build`:

```
article, line 54: 3. by supplying the number of hypotheses (`m`).
arguments of graph_constraint_free(): num_hyp names
graph_constraint_free(m = 3): unused argument (m = 3)
graph_constraint_free(num_hyp = 3): a constraint on 3 hypotheses
EXPECTED: the article names the argument `num_hyp`
```

**Potential fix.** Name the argument:

```diff
-3. by supplying the number of hypotheses (`m`). In this case both the hypothesis weight vector and the transition matrix will be unconstrained.
+3. by supplying the number of hypotheses (`num_hyp`). In this case both the hypothesis weight vector and the transition matrix will be unconstrained.
```

With this change the script prints the article line with `num_hyp`, the name that `graph_constraint_free()` accepts. The tested patch stops there. The line would be clearer still if it named the function as well, for example "by supplying the number of hypotheses to `graph_constraint_free()` (`num_hyp`)", since items 1 and 2 of the list are about `graph_constraint()`.

---

<a name="REG3"></a>
## REG3. gsd-build still reports version 0.3.0, the number of the tag, yet gives different results for the same seed

- Functions: graph_optimise() (through packageVersion("multigrain"))
- Branches: gsd-build only (main was in the same position until ed9a559 of 6 October 2026)
- Potential fix: suggested, not implemented

**What the error is.** `DESCRIPTION` says 0.3.0 at the tag `v0.3.0` and on `gsd-build`, although 15 commits since the tag change `R/` or `src/` on this branch. One of them, `e62dfcf`, changed which rows the optimiser draws when it works on a subsample of the p-values. With the same seed, 4,000 simulated trials and 1,000 rows per stage, a build of the tag returned hypothesis weights 0.559, 0.274, 0.166 and builds of `main` at `324b7ca` and of `gsd-build` returned 0.473, 0.359, 0.168. With all rows used the three agree. These numbers come from three separate builds; the script shows the repository side only. A design report that records "multigrain 0.3.0" therefore does not identify the code that produced the graph. `main` was in the same position (3 such commits at `324b7ca`) until `ed9a559` of 6 October 2026 gave it 0.3.0.9000; it is now at 0.3.0.9002.

**What causes it.** The version was not raised after the release. `.github/workflows/bump-dev-version.yaml:48-53` bumps the development version on each push to `main`, but only when the version already has four components; from 0.3.0 it does nothing, so the sequence did not start until the version was set by hand on `main` in `ed9a559`. `gsd-build` does not contain that commit. `NEWS.md` on this branch lists the subsampling fix under the heading "multigrain 0.3.0" (`NEWS.md:21`); the `NEWS.md` of the tag does not have that line.

**Code showing the problem** ([`reprex/REG3.R`](reprex/REG3.R)):

```r
# REG3: gsd-build still reports version 0.3.0, the number of the tag v0.3.0
# Run from the repository root: Rscript REG3.R   (needs git and the tag v0.3.0; base R only)
# fmt: skip file
git <- function(...) system2("git", c(...), stdout = TRUE)

at_tag <- grep("^Version:", git("show", "v0.3.0:DESCRIPTION"), value = TRUE)
cat("at the tag v0.3.0, DESCRIPTION has:", at_tag, "\n")
cat("in this checkout, DESCRIPTION has :", "Version:", read.dcf("DESCRIPTION", "Version"), "\n")

since <- git("log", "--oneline", "v0.3.0..HEAD", "--", "R", "src")
cat("commits after the tag that change R/ or src/:", length(since), "\n")
cat("one of them:", grep("fixes #12", since, value = TRUE), "\n")

fix <- "independently sample from the full p-value simulation matrix"
cat("that fix is listed in NEWS.md at the tag:", any(grepl(fix, git("show", "v0.3.0:NEWS.md"))), "\n")
news <- readLines("NEWS.md")
heads <- grep("^# ", news)
cat("heading above it in NEWS.md here      :", news[max(heads[heads < grep(fix, news)])], "\n")
cat("EXPECTED: a development version after the tag, and that fix under the development heading\n")
```

Output on `gsd-build`:

```
at the tag v0.3.0, DESCRIPTION has: Version: 0.3.0
in this checkout, DESCRIPTION has : Version: 0.3.0
commits after the tag that change R/ or src/: 15
one of them: e62dfcf Add helper for pval sampling; fixes #12
that fix is listed in NEWS.md at the tag: FALSE
heading above it in NEWS.md here      : # multigrain 0.3.0
EXPECTED: a development version after the tag, and that fix under the development heading
```

**Potential fix.** Merge `main` into `gsd-build`. The branch has not changed the `Version` line, so the merge takes the development version from `main`:

```diff
 Package: multigrain
 Title: Optimising Graphical Approaches to Multiple Testing Procedures
-Version: 0.3.0
+Version: 0.3.0.9002
```

This has not been implemented or tested; no merge was run. After it the script prints 0.3.0 for the tag and the development version for the checkout. `NEWS.md` was rewritten on `main` for the release (`22a9c6e`), so where the entry for the subsampling fix belongs is settled in the same merge.
