# Stress test of `gsd-build-spending`: the errors, one by one

Niamh Fitzgerald, October 2026. Tested on `gsd-build-spending` at `5585caf` (20 October 2026). That branch holds a rebased copy of all of `gsd-build` (the group sequential functions and the efficacy stopping rule `stopping_rule_gsd()`), the joint search over spending parameters and graph, and a merge of `main` (multigrain 1.0.0, on CRAN since 18 October 2026). Every script was also run on `gsd-build` at `8af8adb`.

This folder lists the errors found in stress testing multigrain. Each entry has the same four parts:

1. **What the error is**: what a user does and what happens.
2. **What causes it**: the mechanism, with file and line at `5585caf`.
3. **Code showing the problem**: a short script, followed by the output it gives on `5585caf`. The same script is in `reprex/`.
4. **Potential fix**: a short code change, and what it does.

This branch changes no package code. It adds this folder and nothing else, so every script shows its problem when run against `gsd-build-spending` as it stands.

## The errors, most serious first

83 errors: 7 of severity 1, 14 of severity 2, 36 of severity 3 and 26 of severity 4. "On `main`" says whether the error is also on `main`, which is multigrain 1.0.0 as released on CRAN; the group sequential functions are not on `main`. Every error listed is on both `gsd-build` (`8af8adb`) and `gsd-build-spending` (`5585caf`), so `gsd-build` in an entry's Branches line covers both.

### Severity 1: a wrong number or a crash, with no warning (7)

| ID | Error | Functions | On `main` | Potential fix |
|---|---|---|---|---|
| [A1](1_wrong_results_or_crashes.md#A1) | A gain that is negative for every graph is not optimised | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 46, 67 |
| [A2](1_wrong_results_or_crashes.md#A2) | A gain written for more hypotheses than the p-values have is evaluated outside the rejection matrix | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patches 1, 2, 68 |
| [A3](1_wrong_results_or_crashes.md#A3) | Index 0 is accepted in a gain and reads outside the matrix | trial_success(), trial_success_gsd() | yes | tested, patch 30 |
| [A4](1_wrong_results_or_crashes.md#A4) | sum_to_one_constraint = FALSE switches off the row-sum check, so a graph can hand out alpha twice | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 3 |
| [A5](1_wrong_results_or_crashes.md#A5) | An information fraction above 1 with an uncapped spending function spends more than alpha | transform_pvalues_gsd() | no | tested, patches 19, 65, 70 |
| [ST1](1_wrong_results_or_crashes.md#ST1) | A flat stretch of the boundary table is inverted from its lower end, so a hypothesis is rejected with nothing left to spend | transform_pvalues_gsd() | no | tested, patch 18 |
| [ENV01](1_wrong_results_or_crashes.md#ENV01) | A decimal comma in the session changes the gain that is compiled, with no message | trial_success(); trial_success_gsd() fails with an unrelated error | yes | tested, patches 28, 29 |

### Severity 2: misleading in plausible use, or a result that breaks its own contract (14)

| ID | Error | Functions | On `main` | Potential fix |
|---|---|---|---|---|
| [B1](2_misleading_or_broken_contract.md#B1) | start_graph is ignored when global_search = FALSE | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 47, 70, 73 |
| [B2](2_misleading_or_broken_contract.md#B2) | A fixed constraint value below 0.001 is not kept | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 49 |
| [B3_power](2_misleading_or_broken_contract.md#B3_power) | calc_power_pvals() accepts missing and out-of-range p-values and any alpha | calc_power_pvals(), graph_optimise() | yes | tested, patches 4, 59 |
| [B3_simulators](2_misleading_or_broken_contract.md#B3_simulators) | The simulators do not validate power_nominal, and simulate_pvalues() does not validate nsim | simulate_pvalues(), simulate_pvalues_gsd() | yes | tested, patch 26 |
| [B4](2_misleading_or_broken_contract.md#B4) | The simulators accept matrices that are not correlation matrices | simulate_pvalues(), simulate_pvalues_gsd() | yes | tested, patch 25 |
| [B5](2_misleading_or_broken_contract.md#B5) | A string objective of trial_success() is written into C++ unchecked | trial_success(), trial_success_gsd() | yes | tested, patches 32, 33, 34, 68, 70 |
| [B6](2_misleading_or_broken_contract.md#B6) | The returned graph can be worse than the graph the search started from | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 48, 69 |
| [B7](2_misleading_or_broken_contract.md#B7) | A num_threads of 65,537 or more ends the R session | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 6 |
| [B9](2_misleading_or_broken_contract.md#B9) | A gain, and any saved optimisation result, cannot be used after it is reloaded | trial_success(), trial_success_gsd(), calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd() | yes | tested, patches 36, 60, 68 |
| [ENV02](2_misleading_or_broken_contract.md#ENV02) | Gains built at the same moment in forked workers fail at random | trial_success(), trial_success_gsd() | yes | tested, patch 35 |
| [ENV03_power](2_misleading_or_broken_contract.md#ENV03_power) | Hypothesis names are ignored, so a graph named in another order is evaluated as a different graph | calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid(), graph_optimise(), graph_optimise_gsd() | yes | tested, patches 5, 66 |
| [ENV03_spending](2_misleading_or_broken_contract.md#ENV03_spending) | A spending list named in another order is applied by position, and summary() prints its names in the wrong rows | transform_pvalues_gsd() | no | tested, patches 22, 70 |
| [ENV04](2_misleading_or_broken_contract.md#ENV04) | A local search on all rows depends on the session seed, and changes it | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 50 |
| [MEM1](2_misleading_or_broken_contract.md#MEM1) | The serial kernels compute matrix offsets in 32-bit integers, which overflow above 2^31 p-values | calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise() and graph_optimise_gsd() with num_threads = 1 | yes | tested, patch 7 |

### Severity 3: missing or wrong input validation, and messages that point the wrong way (36)

| ID | Error | Functions | On `main` | Potential fix |
|---|---|---|---|---|
| [C1](3_validation_and_messages.md#C1) | An analysis that spends nothing aborts the whole transform, with advice that cannot help | transform_pvalues_gsd() | no | tested, patch 20 |
| [C2](3_validation_and_messages.md#C2) | Two analyses with nearly the same information abort with a message that blames the spending function | transform_pvalues_gsd() | no | tested, patches 24, 65, 70, 72 |
| [C3](3_validation_and_messages.md#C3) | A missing p-value at a single full-information analysis stays NA, and the power function then blames the caller | transform_pvalues_gsd(), calc_power_pvals_gsd() | no | tested, patch 21 |
| [C4](3_validation_and_messages.md#C4) | grid_size is accepted down to 2, where the type I error is above the level | transform_pvalues_gsd() | no | suggested |
| [C5](3_validation_and_messages.md#C5) | First-analysis repeated p-values are wrong for raw p-values below about 1e-15 | transform_pvalues_gsd() | no | suggested |
| [C6](3_validation_and_messages.md#C6) | An error inside a spending function or gsBound1() surfaces without the hypothesis it belongs to | transform_pvalues_gsd() | no | tested, patch 23 |
| [C7](3_validation_and_messages.md#C7) | The tolerance of a graph constraint is not carried into the optimiser | graph_constraint(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 54 |
| [C8](3_validation_and_messages.md#C8) | A constraint of the wrong size is reported by base R or by the C++ kernel (fixed-sample functions) | graph_constraint(), graph_optimise() | yes | tested, patch 55 |
| [C9](3_validation_and_messages.md#C9) | Hypothesis names are not validated, and plot() fails after the optimisation | graph_constraint(), graph_constraint_free(), graph_random(), plot() | yes | tested, patches 56, 66 |
| [C10](3_validation_and_messages.md#C10) | start_graph is checked for type and size only | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 51, 66 |
| [C11](3_validation_and_messages.md#C11) | Options of the local search are not checked, and a misspelt one is dropped in silence | control_local(), graph_optimise(), graph_optimise_gsd(), print() of a result | yes | tested, patch 52 |
| [C12](3_validation_and_messages.md#C12) | control_global() can replace the objective, the bounds and the start graphs of the global search | control_global(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 53 |
| [C13](3_validation_and_messages.md#C13) | A flat sum of a few hundred terms cannot be turned into a gain: the C stack runs out | trial_success(), trial_success_gsd() | yes | suggested |
| [C14](3_validation_and_messages.md#C14) | trial_success_gsd() cannot compile a sign applied to a signed value | trial_success_gsd() | no | tested, patch 37 |
| [C15](3_validation_and_messages.md#C15) | trial_success() fails in the C++ compiler on a value taken from a named vector | trial_success() | yes | tested, patches 29, 39 |
| [C16](3_validation_and_messages.md#C16) | trial_success() cannot build a gain with a constant that R prints in exponent form (100000, 0.0001) or with a negative constant | trial_success() | yes | tested, patches 28, 38 |
| [C17](3_validation_and_messages.md#C17) | A mistyped hypothesis index is accepted, however large | trial_success(), trial_success_gsd() | yes | tested, patch 41 |
| [C18](3_validation_and_messages.md#C18) | A discount table that the gain never applies is accepted without a word | trial_success_gsd() | no | tested, patch 42 |
| [C19](3_validation_and_messages.md#C19) | Every gain keeps a shared library loaded and build files on disk until the session ends | trial_success(), trial_success_gsd() | yes | suggested |
| [C20](3_validation_and_messages.md#C20) | A custom_power entry named like a built-in output field, including the two fields of the stopping rule, is hidden behind it | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 13 |
| [C21](3_validation_and_messages.md#C21) | calc_power_pvals_gsd() refuses a gain that does not mention the last hypothesis | calc_power_pvals_gsd() | no | suggested |
| [C22](3_validation_and_messages.md#C22) | is_graph_valid() stops on a missing value, and normalise_sum() keeps negative weights | is_graph_valid(), normalise_sum(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patches 10, 11 |
| [C23](3_validation_and_messages.md#C23) | An epsilon edge below about 1e-13 gives wrong local levels | calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid() | yes | suggested |
| [ENV05](3_validation_and_messages.md#ENV05) | With a negative scipen option, or a deleted working directory, no gain can be built | trial_success(), trial_success_gsd() | yes | tested, patches 28, 43, 44 |
| [MEM3](3_validation_and_messages.md#MEM3) | A kernel call cannot be interrupted | calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 12 |
| [DOC12](3_validation_and_messages.md#DOC12) | The error for `r1 + r2 && r3` does not say that parentheses are needed | trial_success_gsd() | no | tested, patch 40 |
| [DOC14](3_validation_and_messages.md#DOC14) | Replacing any other element of a graph constraint gives "object 'output' not found" | graph_constraint() (the replacement methods `$<-`, `[[<-` and `[<-` of its objects) | yes | tested, patch 57 |
| [DOC17b](3_validation_and_messages.md#DOC17b) | Integer weights are refused although hyp_weight is documented as numeric | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 14 |
| [DOC17c](3_validation_and_messages.md#DOC17c) | normalise_sum() accepts a negative tolerance | normalise_sum() | yes | tested, patch 11 |
| [DOC17d](3_validation_and_messages.md#DOC17d) | normalise_sum() does not check fixed_idx against the length of x | normalise_sum() | yes | tested, patch 11 |
| [DOC17f](3_validation_and_messages.md#DOC17f) | plot(x, root = 7) on a graph with 4 hypotheses gives a raw igraph error | plot() and autoplot() of a result and of a graph constraint | yes | suggested |
| [DOC17g](3_validation_and_messages.md#DOC17g) | sum_to_one_constraint = NA gives R's own error, not a message about the argument | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 10 |
| [SR1](3_validation_and_messages.md#SR1) | A stopping rule that holds when nothing has been rejected is accepted as an efficacy rule | stopping_rule_gsd(), calc_power_pvals_gsd(), graph_optimise_gsd() | no | tested in a scratch build |
| [SR2](3_validation_and_messages.md#SR2) | A mistyped rejection indicator in a stopping rule gets advice to inject a variable | stopping_rule_gsd() | no | tested in a scratch build (changes one of Alex's tests) |
| [UT2](3_validation_and_messages.md#UT2) | A gsDesign spending function with a required parameter fails with R's own error | transform_pvalues_gsd() | no | tested in a scratch build |
| [UT3](3_validation_and_messages.md#UT3) | Information fractions that never reach 1 are accepted silently, so the level is never spent in full | transform_pvalues_gsd() | no | tested in a scratch build |

### Severity 4: documentation, printing, housekeeping, and internal routines no user reaches (26)

| ID | Error | Functions | On `main` | Potential fix |
|---|---|---|---|---|
| [MEM4](4_documentation_and_housekeeping.md#MEM4) | Two internal routines lack a guard: an out-of-bounds read and a division by zero | none exported (internal graph_violation_score_cpp(), graph_shortcut_parallel(), graph_shortcut_gsd_parallel()) | yes | tested, patches 8, 9 |
| [D_ggplot2_optional](4_documentation_and_housekeeping.md#D_ggplot2_optional) | The plot help calls ggplot2 an optional dependency, but the package cannot be loaded without it | plot() and autoplot() for graph constraints and optimised graphs | yes | suggested |
| [D_global_output](4_documentation_and_housekeeping.md#D_global_output) | result$global_output is an invalid S4 object and cannot be printed | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 58 |
| [D_graphics_undeclared](4_documentation_and_housekeeping.md#D_graphics_undeclared) | The namespace imports plot from graphics, which DESCRIPTION does not declare | plot() for graph constraints and optimised graphs | yes | suggested |
| [D_local_weights](4_documentation_and_housekeeping.md#D_local_weights) | The unused internal calc_local_weights() crashes for zero hypotheses and reads past a matrix that is too small | none exported (internal calc_local_weights()) | yes | suggested |
| [D_plot_rounding](4_documentation_and_housekeeping.md#D_plot_rounding) | From 5 hypotheses up, plot() labels an edge of 0.001 as 0 | plot() and autoplot() of a result and of a graph constraint, print() of a result | yes | suggested |
| [D_power_nominal](4_documentation_and_housekeeping.md#D_power_nominal) | The help calls power_nominal the power "at its final analysis"; it is the power at an information fraction of 1 | simulate_pvalues_gsd() | no | tested, patch 27 |
| [DOC1](4_documentation_and_housekeeping.md#DOC1) | The get-started article codes "both primaries" where its text and formula say "at least one" | trial_success() (as used in the get-started article and in data-raw/) | yes | suggested |
| [DOC2](4_documentation_and_housekeeping.md#DOC2) | The results printed in the get-started article are stored objects in an old layout | graph_optimise(), graph_optimal_get_control() and summary() of an optimised graph (as shown in the get-started article) | yes | suggested |
| [DOC4](4_documentation_and_housekeeping.md#DOC4) | A sentence of ?trial_success is cut off after "60" | trial_success() (help page) | no | tested, patches 31, 61 |
| [DOC6](4_documentation_and_housekeeping.md#DOC6) | A roxygen-style link in the trial success article is shown as literal brackets | trial_success() (article "Trial success measures") | no | tested, patch 63 |
| [DOC7](4_documentation_and_housekeeping.md#DOC7) | NEWS.md announces neither the group sequential functions nor the new gsDesign dependency | simulate_pvalues_gsd(), transform_pvalues_gsd(), trial_success_gsd(), graph_optimise_gsd(), graph_optimize_gsd(), calc_power_pvals_gsd() | no | tested, patches 64, 71 |
| [DOC8](4_documentation_and_housekeeping.md#DOC8) | The script in data-raw no longer rebuilds the bundled dataset | graph_optimal_example (dataset), graph_optimise() | yes | suggested |
| [DOC9](4_documentation_and_housekeeping.md#DOC9) | A development vignette documents optimize_N(), which was removed, and its data file sits with the published articles | none exported (optimise_N() and optimize_N() were removed in version 0.2.0) | yes | suggested |
| [DOC10](4_documentation_and_housekeeping.md#DOC10) | The help example of calc_power_pvals() calls a sum of rejections "average_power" | calc_power_pvals() (help page) | yes | tested, patch 15 |
| [DOC11](4_documentation_and_housekeeping.md#DOC11) | The help text of sum_to_one_constraint reads as the opposite of what the argument does | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() (help pages) | yes | tested, patch 16 |
| [DOC13](4_documentation_and_housekeeping.md#DOC13) | Nothing a user reads says that defining a gain needs a C++ toolchain every time | trial_success(), trial_success_gsd() | yes | tested, patch 45 |
| [DOC15](4_documentation_and_housekeeping.md#DOC15) | The get-started article has a dead link to the graph constraint article and a chunk with two labels | graph_constraint() (get-started article) | yes | tested, patch 63 |
| [DOC16](4_documentation_and_housekeeping.md#DOC16) | Package metadata is out of step: two unused website dependencies and an incomplete word list | none (DESCRIPTION, NEWS.md, inst/WORDLIST) | yes | suggested |
| [DOC17a](4_documentation_and_housekeeping.md#DOC17a) | The result name of a single custom_power measure is not documented | calc_power_pvals(), calc_power_pvals_gsd() (help pages) | yes | tested, patch 17 |
| [DOC17h](4_documentation_and_housekeeping.md#DOC17h) | The graph constraint article calls the argument for the number of hypotheses `m`; it is `num_hyp` | graph_constraint_free() | yes | tested, patch 63 |
| [DOC18](4_documentation_and_housekeeping.md#DOC18) | The README calls Getting Started a walk-through of its example, but the two use different inputs | none (README and the Getting Started article) | yes | suggested |
| [DOC19](4_documentation_and_housekeeping.md#DOC19) | Text errors in the Getting Started and Graph constraints articles | none (articles Getting Started and Graph constraints) | yes | suggested |
| [UT4](4_documentation_and_housekeeping.md#UT4) | summary() of an unnamed list of spending functions prints deparsed code | transform_pvalues_gsd(), summary() of its result | no | tested in a scratch build |
| [UT5](4_documentation_and_housekeeping.md#UT5) | A stale Quarto intermediate of the trial success article is committed | none (vignettes/articles/trial_success.rmarkdown) | no | suggested |
| [UT6](4_documentation_and_housekeeping.md#UT6) | The design record's suggested way to supply the classical O'Brien-Fleming boundary fails | transform_pvalues_gsd() (as suggested in dev/gsd_design_record.md) | no | suggested |

## Files

| File | Contents | Entries |
|---|---|---|
| [`1_wrong_results_or_crashes.md`](1_wrong_results_or_crashes.md) | Severity 1 | 7 |
| [`2_misleading_or_broken_contract.md`](2_misleading_or_broken_contract.md) | Severity 2 | 14 |
| [`3_validation_and_messages.md`](3_validation_and_messages.md) | Severity 3 | 36 |
| [`4_documentation_and_housekeeping.md`](4_documentation_and_housekeeping.md) | Severity 4 | 26 |
| `reprex/<ID>.R` | The short script of each entry | 83 |
| [`stopping_rule/`](stopping_rule/) | Checks of the stopping rule, with their output (see "The stopping rule: what was checked") | 3 scripts |
| [`rerun_5585caf/`](rerun_5585caf/) | The rerun on `gsd-build-spending`: every script on both builds compared, and the `R CMD check` and test suite results | 2 files |
| [`fast_shortcut_and_family_opt/`](fast_shortcut_and_family_opt/) | A separate stress test of two newer branches, `fast-shortcut` and `family-opt` (21 October 2026), with its own README | 5 findings |

## IDs

The IDs are those of the stress-test reports: A, B, C and D from round 1 (most to least serious), ST, ENV, MEM, DOC and REG from round 2 (statistics, environment, memory, documentation, comparison with `main`), SR for the stopping rule, and UT for findings of the user testing of 5 October (`dev/review/gsd_user_testing/`) that are still present. Findings that turned out to be one defect share an entry: B7 with MEM2, B9 with ENV06, C1 with ST2, C19 with MEM5, DOC13 with ENV07, and DOC17e inside B3_simulators. B3 and ENV03 each have two entries, one per group of functions. Gaps in the numbering (B8 and DOC5, DOC3, REG1 to REG3, UT1) are findings that were fixed or merged into another entry.

## Summary

- 83 errors. 7 of them give a wrong number or end the R session with no warning: A1 to A5, ST1 and ENV01.
- 59 are also on `main`, and so in multigrain 1.0.0 on CRAN. `main` was submitted to CRAN on 8 October 2026 (`7884824`) and published on 18 October. The `R/` and `src/` folders of the CRAN release, of `7884824` and of `main` today (`16f66d0`) are identical (checked on 21 October). The fixed-sample code is the same on `main` and on the group sequential branches, so those errors can be fixed on either; a fix on `main` would reach CRAN in the next release.
- 58 errors have a tested fix in a separate patch series, 5 (SR1, SR2, UT2, UT3 and UT4) a fix tried in a scratch build, and 20 a suggested one (see "Potential fixes" below).
- Outside these entries the statistics held up. Familywise error, the rejection thresholds, the look-back rule, power and the new stopping rule agreed with independent references. The sections at the end list what was looked at and is not an error.
- With no stopping rule, the stopping-rule update changed no result: p-values, powers and optimised graphs are bit-for-bit the same as before it. `gsd-build-spending` gives bit-for-bit the same results again (`stopping_rule/SR_regression_compare_5585caf.out`).
- On `gsd-build-spending`, `R CMD check` runs the examples again and the test suite passes apart from 18 plot snapshots, which fail in the same way on `gsd-build` in this environment (`rerun_5585caf/test_suite_and_check.txt`).

## Running the scripts

Install the `gsd-build-spending` build of multigrain, then for example:

```
Rscript dev/review/stress_test/reprex/A3.R
```

- A script whose header says "Run from the repository root" reads files of the repository by relative path. The others run from anywhere.
- Every script ends with a line starting `EXPECTED:`, which says what a correct package would have done.
- The scripts are kept compact so that each fits on one screen. They carry the comment `# fmt: skip file` so that the repository's formatter (`air`) leaves them as they are.
- Each took under 30 seconds here, most under 10. Most of that is the C++ compilation inside `trial_success()` and `trial_success_gsd()`.
- No script ends the session it runs in. Where the error is a crash (A2, A3, B7, D_local_weights), the call is made in a child process and its exit status is printed; 139 is a segmentation fault.
- Some output changes from run to run: values read from memory outside a matrix (A2, A3, MEM4), timings (C17, MEM3), the stack figure in C13 and the number of failed workers (ENV02).
- ENV01 shows its second part only on a machine with a decimal comma locale installed (the output shown used `de_DE.UTF-8`). ENV02 uses forked workers and MEM3 sends a signal with `kill`, so those two are for Linux and macOS.
- The output shown was captured on 21 October 2026 on `5585caf`, in an `en_US.UTF-8` session with R 4.3.3 on Linux (x86_64, g++ 13.3.0, 2 cores), gsDesign 3.11.0 (installed without its table-formatting imports gt and r2rtf, which multigrain never calls), Rcpp 1.0.12, nloptr 2.0.3, GA 3.2.5, mvtnorm 1.2.4, RcppParallel 6.2.1 and rlang 1.3.0. The same setup reproduced every output of the second version on `8af8adb`, apart from the run-to-run values above. Nothing here was run on Windows or macOS.

## Potential fixes

- **tested (patch N)**: the change exists in a separate series of 73 commits, written on `gsd-build` before the stopping rule was added (`ee91a11`); 58 of the errors here have one. That series is not part of this branch and has not been rebased onto `8af8adb` or `5585caf`. N is the position of the commit in the series, and the code shown in the entry is the final state of the series, cut down to the lines that matter. On the series as a whole the test suite passed (658 tests; the only failures were 18 plot snapshots that fail in the same way on `gsd-build` in that environment), `R CMD check` (run without the tests and the vignettes) gave no error or warning, and every script of this folder was rerun on it. Patches that touch files changed by the stopping rule are likely to conflict on a rebase; the entries name the ones known to be affected: 13 (C20), 31 and 61 (DOC4), 55 (C8), 64 and 71 (DOC7). Patch 62 (the pkgdown index) is no longer needed.
- **tested in a scratch build**: SR1, SR2, UT2, UT3 and UT4. The code shown was applied to a copy of `8af8adb`, the script rerun and the full test suite run; it is in no commit. `R/stopping_rule_gsd.R`, which SR1 and SR2 change, is the same on `5585caf`; its test file differs only by a lint comment, which moves its lines down by one. UT2 to UT4 change `R/transform_pvalues_gsd.R`, which `5585caf` extends for spending specs, so those three may need small adjustments there.
- **suggested, not implemented**: there is no code for it on any branch. Where a suggestion was tried in a throwaway session, the entry says so.
- Several fixes are a judgement call (an error where a warning would also do, a tolerance, a limit). The entry then names the alternative.
- `_pkgdown.yml` and `NEWS.md` were rewritten on `main` after `gsd-build` branched (`aad5556`, `22a9c6e`), and `gsd-build-spending` has now merged `main`. The fix shown for DOC7 applies to `NEWS.md` at `5585caf`; patches 64 and 71 of the series predate both and will conflict.

## Looked at, and not listed as an error

These came up in the same testing. They are design questions or properties to know about, so they have no entry.

- **The optimiser can miss with 4 to 6 hypotheses.** Against an independent optimiser on 28 random problems (20,000 trials each), default runs with 3 hypotheses were within 0.001 of the best known graph every time. With 4 to 6 hypotheses, 10 of 40 runs fell short by more than 0.002, the worst by 0.021 (about 2% of the gain), and two seeds could differ by that much. Running several seeds and keeping the best graph helps today. A possible change: start the local search from the best few candidates of the global stage.
- **The reported gain is optimistic at small simulation counts.** The graph is optimised and scored on the same simulated trials. With 4 hypotheses the reported gain was above the true one by 0.070 on average at 500 trials, 0.048 at 2,000 and 0.008 at 10,000. Scoring the final graph on fresh p-values with `calc_power_pvals()` removes this.
- **Alpha cannot be discarded.** A complete constraint row must sum to 1, so a terminal node cannot be written as a constraint and the optimiser always recycles. A "sink" hypothesis whose p-values are all 1 and whose weight is fixed at 0 works today and may be worth documenting.
- **Correlation across endpoints with different information fractions.** `simulate_pvalues_gsd()` uses rho times sqrt(min t / max t), as the design record says (section 4.7). That is exact when the fractions index the same subjects. For an event-driven pair such as PFS and OS it is a modelling choice that affects power and the optimal graph, not the error rate. The help could state the assumption.
- **A gain must mention the highest-numbered hypothesis.** A gain written as `r1` is refused for a design with 3 hypotheses; `r1 + 0 * r2 + 0 * r3` is the way round it. Entry C21 covers the one place where this is stricter than it needs to be.
- **The kernels reject on `p < level`, not `p <= level`.** Documented. It differs from gMCPLite and graphicalMCP on exact ties only.

## The stopping rule: what was checked

What was checked, besides SR1 and SR2. The scripts and their output are in [`stopping_rule/`](stopping_rule/); `SR_checks.R` passes 16 of 16 on both builds, and `SR_inputs.R` gives the same output on both.

- **The kernel is right.** With no rule, the group sequential kernel agrees exactly with an independent implementation of the graphical procedure, written from its definition (2 to 5 hypotheses, 2 to 4 analyses, random graphs). With a rule, the stopped decision times are exactly the unstopped ones cut at the first interim where the rule holds, for 36 designs and four rules, and so is the stopping look. A list of conditions applies condition k at interim k. The serial and parallel kernels agree to the bit.
- **Error control holds.** Under the global null and under a partial null (200,000 trials, 4 hypotheses, 3 analyses), familywise error was at most 0.0239 with no rule and with three rules.
- **The outputs are consistent.** No local, disjunctive or conjunctive power goes up under any rule; `stop_distribution` sums to 1 and `mean_stop_look` is its mean; power at the first interim is untouched; with no rule, the mass before the last analysis is exactly the trials that rejected everything. With one analysis a rule changes nothing.
- **The optimiser uses the rule.** The gain that `graph_optimise_gsd()` reports equals `calc_power_pvals_gsd()` on the returned graph with the same rule, and the result records the rule and prints it.
- **Nothing changes without a rule.** With no stopping rule, `gsd-build` gives bit-for-bit the same p-values, powers and optimised graphs as before the rule was added (`ee91a11`; `stopping_rule/SR_regression_compare.out`), and `gsd-build-spending` gives the same as `gsd-build` (`stopping_rule/SR_regression_compare_5585caf.out`).
- **The help examples run.** Called one by one with `example()`, the examples of the eight group sequential help pages run (six on `gsd-build`). On `gsd-build-spending`, `R CMD check` runs them too; on `gsd-build` it does not, since the examples of `trial_success()` there do not parse (the former entry B8).
- **A rule only constrains the design; the gain cannot value stopping.** The stopping look was a gain symbol (`s`) for one commit and was withdrawn on 13 October as too complex (`bfb5291`; `065c358` on `gsd-build`). So a gain sees only which hypotheses were rejected and when, and a rule only removes rejections. For any gain that does not decrease when a rejection is added, every rule therefore lowers the gain of a given graph or leaves it the same. The optimiser cannot use a rule to trade power for an earlier end, only find the best graph given a rule fixed in the protocol. This is a design choice, not an error. It matters for trials where stopping early is worth something in itself.
- **Optimise with the rule in place.** In `SR_checks.R` (3 hypotheses, 2 analyses, stop once H1 is rejected), the graph optimised with the rule had a gain of 1.766 under that rule. The graph optimised without it scored 1.619 under the same rule. Both figures are on the trials used for the optimisation, so both are optimistic; the gap is what matters.
- **The truth table is quick enough.** It has 2^m rows per interim and is built in R: 0.1 s for 12 hypotheses and 3 interims, about 2 to 3 s for 16. 17 hypotheses are refused with a clear message.
- **Other input is handled well.** `SR_inputs.R` tries 33 awkward inputs. Apart from SR1, SR2 and the small items below, each is accepted or refused as the help says, with a message that names the problem: the single `&` and `|`, `isTRUE()`, decision times, `NULL`, `NA`, empty lists, rules referring to too many hypotheses, too few or too many conditions, conditions that return a number or `NA`, and use with the fixed-sample optimiser.

## Small items without an entry

Of the same kind as entry C22, and too small for an entry each. On `gsd-build` and `gsd-build-spending`:

- `normalise_sum(c(Inf, 1))` and `normalise_sum(c(NA, 1))` stop with R's own "missing value where TRUE/FALSE needed".
- `is_graph_valid()` given a list as `hyp_weight` stops with "invalid 'type' (list) of argument".
- One line of prose in `R/trial_success.R` (line 12, and so `man/trial_success.Rd:50`) still has typographic quotes. They render, so nothing breaks; the former entry B8 was the same quotes inside an example.

In the stopping rule:

- `stopping_rule_gsd("r1")` is one condition applied at every interim, but `stopping_rule_gsd(c("r1"))` counts as one condition per interim, so with 3 analyses it is refused ("It gives 1 condition"). The two look the same to a user, and the help describes both forms. The refusal message is clear, so it is listed here only.
- A condition that returns a number (`r1 + r2`) or `NA` (`r1 / r2 > 0`) is accepted by `stopping_rule_gsd()` and refused only when the rule is used. The message then is clear and names the rejection set. The rule could be checked on creation on the empty set, as in SR1's fix.
- The kernels treat `NA` in the truth table as `TRUE`, since `NA_LOGICAL` is a non-zero integer (`src/graph_shortcut_gsd.cpp:253` and `:398`). No user reaches this: `.gsd_stop_table()` refuses any value that is not `TRUE` or `FALSE`. It is of the same kind as MEM4.

## Other branches

Two newer branches start from `main` and are not in `gsd-build-spending`: `fast-shortcut` (`62bba6a`, a faster shortcut kernel) and `family-opt` (`851f58e`, graphs of families of hypotheses). Their stress test is in [`fast_shortcut_and_family_opt/`](fast_shortcut_and_family_opt/), with its own README.

- `fast-shortcut`: no new errors. The new kernel gives the same rejections as the old one, and MEM1 is narrowed.
- `family-opt`: five findings, kept there as they concern a branch this catalogue does not describe. FAM1 (severity 2) is a missing p-value inside a family; A4 (severity 1) and MEM1 (severity 2) reach the families code; FAM3 (severity 3) widens C20; FAM2 (severity 4) is about node labels.

## Not tested

- Windows and macOS.
- A p-value matrix above 2^31 elements (entry MEM1 was established by reading the code and by arithmetic; the machine had too little memory to run it).
- The branches `sample-size-pub` and `plan-for-sparsity`, beyond reading how they would merge.
- The stopping rule on a real design (the flu vaccine trial is proprietary and is not used here), and with spending functions other than O'Brien-Fleming type.
- The fix series on `gsd-build` or `gsd-build-spending`: it was written before the stopping rule and has not been rebased (it is not in this repository).
- The joint search over spending parameters and graph, beyond running these scripts on the branch that holds it. Its own stress test (15 October 2026, on `e45ee1f`, an earlier state of `gsd-build-spending`) found ten further items, HS1 to HS10, which are written up separately and are not entries here.

## Changes from earlier versions

### This version: rerun on `gsd-build-spending` (21 October 2026)

The second version (14 October 2026, commit `5ff1ee8`) described `gsd-build` at `8af8adb`. For this version the commit was moved onto `gsd-build-spending` at `5585caf`, and every script was rerun on both builds. [`rerun_5585caf/script_comparison.txt`](rerun_5585caf/script_comparison.txt) compares them script by script.

- **Removed, fixed on `gsd-build-spending`:**
  - B8: the examples of `trial_success()` now parse, so `R CMD check` runs the examples again.
  - REG3: the merge of `main` brought a development version number, 1.0.0.9000. The subsampling fix the entry used as its example is no longer listed in `NEWS.md` at all, since the merge replaced the older sections of that file.
  - UT1: the merge of `main` brought `skip_if_not_installed()` to the tests that need a suggested package.
- **Narrowed:** DOC7 (`NEWS.md` now names `transform_pvalues_gsd()`; `simulate_pvalues_gsd()`, `graph_optimize_gsd()` and gsDesign are still missing) and DOC16 (the version number is fixed; the website dependencies and the word list are not).
- **Reworded:** DOC9 (the merge of `main` removed the `NEWS.md` line that recorded the removal of `optimize_N()`).
- **Script changed:** D_ggplot2_optional finds the help page by its alias, since the file was renamed. The output is the same on both builds.
- **Output changed in a line number only:** DOC13 and UT6.
- **Line references:** 112 references moved to their lines at `5585caf`. Every other reference points at a line that did not move.
- **Checks:** `R CMD check` and the test suite, on both builds (`rerun_5585caf/test_suite_and_check.txt`). The stopping-rule checks were rerun: 16 of 16 pass, and with no rule `5585caf` matches `8af8adb` bit for bit.
- Every other entry gives the same output on `5585caf` as on `8af8adb`, apart from the run-to-run values listed under "Running the scripts".

### Second version (14 October 2026)

The first version of this folder (7 October 2026, commit `cae536a`) was written for `gsd-build` at `ee91a11`. For the second version every script was rerun on `8af8adb`, each output was captured again, and every line reference was moved.

- **Removed, fixed on `gsd-build`:** DOC3. The stopping-rule update added the pkgdown group of help topics that the entry suggested, and pkgdown now builds the reference index.
- **Narrowed:** B8 (the help page is now well formed; its examples still do not parse) and C8 (the group sequential optimiser now names both sizes; the fixed-sample functions do not).
- **Widened:** C20 (two more built-in names).
- **Still present, with new output:** DOC7 and REG3.
- **Added:** SR1 and SR2, in the stopping rule; DOC18 and DOC19, documentation errors found in round 1 that the first version left out; UT1 to UT6, findings of the user testing of 5 October that are still present.
- Every other entry gives the same output as on `ee91a11`, apart from the run-to-run values listed under "Running the scripts".
