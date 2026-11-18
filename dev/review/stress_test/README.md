# Stress test of `gsd-build-spending`: the errors, one by one

Niamh Fitzgerald, October and November 2026. Tested on `gsd-build-spending` at `31ada01` (5 November 2026). That branch holds a rebased copy of all of `gsd-build` (the group sequential functions and the efficacy stopping rule `stopping_rule_gsd()`), the joint search over spending parameters and graph, and two merges of `main`: multigrain 1.0.0 (on CRAN since 18 October 2026), and on 4 November the faster graphical shortcut and the renamed verbosity option. Every script of the earlier versions was also run on `gsd-build-spending` at `5585caf` (the head tested on 21 October) and on `main` at `508d0b7`; the earlier versions ran them on `gsd-build` at `8af8adb`. The scripts new in this version (HS1 to HS10) were run on `31ada01` only, and ENV08 on all three.

This folder lists the errors found in stress testing multigrain. Each entry has the same four parts:

1. **What the error is**: what a user does and what happens.
2. **What causes it**: the mechanism, with file and line at `31ada01`.
3. **Code showing the problem**: a short script, followed by the output it gives on `31ada01`. The same script is in `reprex/`.
4. **Potential fix**: a short code change, and what it does.

This branch changes no package code. It adds this folder and nothing else, so every script shows its problem when run against `gsd-build-spending` as it stands.

## The errors, most serious first

94 errors: 7 of severity 1, 16 of severity 2, 38 of severity 3 and 33 of severity 4. "On `main`" says whether the error is also on `main` (`508d0b7`, 23 October 2026); the group sequential functions are not on `main`. `main` differs from multigrain 1.0.0 on CRAN only in the graphical shortcut and the verbosity option, so the column also stands for the CRAN release, apart from MEM1 (in the release, fixed on `main`) and ENV08 (on `main`, not in the release). The 83 errors of the earlier versions are on both `gsd-build` (`8af8adb`) and `gsd-build-spending` (`31ada01`), so `gsd-build` in an entry's Branches line covers both. The HS entries, from the stress test of the joint spending search, are on `gsd-build-spending` only.

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

### Severity 2: misleading in plausible use, or a result that breaks its own contract (16)

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
| [MEM1](2_misleading_or_broken_contract.md#MEM1) | The serial group sequential kernel computes matrix offsets in 32-bit integers, which overflow above 2^31 p-values | calc_power_pvals_gsd() and graph_optimise_gsd() with num_threads = 1; in CRAN 1.0.0 also calc_power_pvals() and graph_optimise() | no (fixed there; yes in CRAN 1.0.0) | tested, patch 7 |
| [HS1](2_misleading_or_broken_contract.md#HS1) | When the genetic algorithm's graph is kept, print() and summary() describe the local search's design | graph_optimise_gsd() with a spending spec, print(), summary() | no | print note tested on `e45ee1f`; full fix suggested |
| [HS2](2_misleading_or_broken_contract.md#HS2) | The plateau tolerance is a fixed 5e-4 in gain units, whatever the gain's scale or the simulation error | print() of a joint spending result; article gsd-joint-spending | no | suggested |

### Severity 3: missing or wrong input validation, and messages that point the wrong way (38)

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
| [HS3](3_validation_and_messages.md#HS3) | An empty or blank id is accepted and gives a parameter with no name | sf_hsd_opt() | no | tested on `e45ee1f` |
| [HS6](3_validation_and_messages.md#HS6) | A value above the lattice is told its nearest nodes are "0 and NA" | resolve_pvalues_gsd() | no | tested on `e45ee1f` |

### Severity 4: documentation, printing, housekeeping, and internal routines no user reaches (33)

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
| [ENV08](4_documentation_and_housekeeping.md#ENV08) | The old name of the verbosity option is ignored without a message | multigrain_verbosity() and every `verbose` argument that defaults to it | yes (not in CRAN 1.0.0) | tested in a session |
| [HS4](4_documentation_and_housekeeping.md#HS4) | The spending parameter cannot be optimised on its own (fixed graph, or one hypothesis) | graph_optimise_gsd(), graph_constraint(), graph_constraint_free() | no | suggested |
| [HS5](4_documentation_and_housekeeping.md#HS5) | print() gives the wrong step when the bounds are not multiples of the step | print() of a joint spending result | no | tested on `e45ee1f` |
| [HS7](4_documentation_and_housekeeping.md#HS7) | A short-circuited member of a shared parameter is labelled with the start value | transform_pvalues_gsd() with a spec, print() | no | tested on `e45ee1f` (a judgement call) |
| [HS8](4_documentation_and_housekeeping.md#HS8) | sf_hsd_opt() prints as a bare function with attributes | sf_hsd_opt() | no | tested on `e45ee1f` |
| [HS9](4_documentation_and_housekeeping.md#HS9) | The article's fresh-draws check cannot show the optimism it is introduced to measure | none (article gsd-joint-spending) | no | suggested |
| [HS10](4_documentation_and_housekeeping.md#HS10) | The article's data script stops at its report on R older than 4.4 | none (data-raw/gsd-joint-spending-vignette.R) | no | suggested |

## Files

| File | Contents | Entries |
|---|---|---|
| [`1_wrong_results_or_crashes.md`](1_wrong_results_or_crashes.md) | Severity 1 | 7 |
| [`2_misleading_or_broken_contract.md`](2_misleading_or_broken_contract.md) | Severity 2 | 16 |
| [`3_validation_and_messages.md`](3_validation_and_messages.md) | Severity 3 | 38 |
| [`4_documentation_and_housekeeping.md`](4_documentation_and_housekeeping.md) | Severity 4 | 33 |
| `reprex/<ID>.R` | The short script of each entry | 94 |
| [`stopping_rule/`](stopping_rule/) | Checks of the stopping rule, with their output (see "The stopping rule: what was checked") | 3 scripts |
| [`rerun_31ada01/`](rerun_31ada01/) | This rerun (18 November 2026): the scripts on `5585caf`, `31ada01` and `main` compared, `R CMD check` and the test suite, the stopping-rule checks on `31ada01` (`SR_*_31ada01.out`), and the outputs of the checks of the merged shortcut (`shortcut/`) | 5 files and a folder |
| [`rerun_5585caf/`](rerun_5585caf/) | The rerun of 21 October 2026 on `5585caf`: every script on it and on `8af8adb` compared, and the `R CMD check` and test suite results | 2 files |
| [`fast_shortcut_and_family_opt/`](fast_shortcut_and_family_opt/) | A separate stress test of two newer branches, `fast-shortcut` and `family-opt` (21 October 2026), with its own README | 5 findings |
| [`split_merge_and_vignette/`](split_merge_and_vignette/) | A separate stress test of two newer branches, `split-merge` and `trial_success_vignette` (18 November 2026), with its own README | see its README |

## IDs

The IDs are those of the stress-test reports: A, B, C and D from round 1 (most to least serious), ST, ENV, MEM, DOC and REG from round 2 (statistics, environment, memory, documentation, comparison with `main`), SR for the stopping rule, UT for findings of the user testing of 5 October (`dev/review/gsd_user_testing/`) that are still present, and HS for the stress test of the joint spending search (15 October, on `e45ee1f`, an earlier state of `gsd-build-spending`), whose ten findings are entries from this version on. Findings that turned out to be one defect share an entry: B7 with MEM2, B9 with ENV06, C1 with ST2, C19 with MEM5, DOC13 with ENV07, and DOC17e inside B3_simulators. B3 and ENV03 each have two entries, one per group of functions. Gaps in the numbering (B8 and DOC5, DOC3, REG1 to REG3, UT1) are findings that were fixed or merged into another entry.

## Summary

- 94 errors. 7 of them give a wrong number or end the R session with no warning: A1 to A5, ST1 and ENV01. This version adds 11: the ten findings of the joint spending stress test (HS1 to HS10), rechecked on `31ada01` with new scripts, and ENV08, which came with the second merge of `main` (Alex's report of 5 November notes it too). None of the 83 earlier errors was fixed by that merge; MEM1 was narrowed.
- 59 are also on `main` (`508d0b7`). 59 are in multigrain 1.0.0 on CRAN: the same set, with MEM1 in place of ENV08. `main` was submitted to CRAN on 8 October 2026 (`7884824`) and published on 18 October; the CRAN release's `R/` and `src/` are those of `7884824` (checked again on 18 November against the github.com/cran mirror). Since then `main` has changed only the graphical shortcut (`src/graph_shortcut.cpp`, PR #48) and the verbosity option (#52). The errors marked "yes" reproduce on `main`, so they can be fixed there, and a fix on `main` would reach CRAN in the next release. The fixed-sample files on `gsd-build-spending` also carry group sequential additions (in `R/calc_power.R`, `R/optimisation.R`, `R/trial_success.R` and `R/graph_optimal.R`), so their line numbers on `main` differ from those given here.
- 58 errors have a tested fix in a separate patch series, 5 (SR1, SR2, UT2, UT3 and UT4) a fix tried in a scratch build of `8af8adb`, 6 (HS1's print note, HS3, HS5, HS6, HS7 and HS8) a fix tried in a scratch build of `e45ee1f`, 1 (ENV08) a fix tried in a session, and 24 a suggested one (see "Potential fixes" below).
- Outside these entries the statistics held up. Familywise error, the rejection thresholds, the look-back rule, power and the new stopping rule agreed with independent references. The merged shortcut, which `gsd-build-spending` now uses for every fixed-sample calculation, gave the same rejections as the old kernel and as graphicalMCP in every check, including the two fallbacks added just before the merge ("The merged shortcut: what was checked" below). The sections at the end list what was looked at and is not an error.
- With no stopping rule, the stopping-rule update changed no result: p-values, powers and optimised graphs are bit-for-bit the same as before it. `gsd-build-spending` gives bit-for-bit the same results again, at `5585caf` and at `31ada01` (`stopping_rule/SR_regression_compare_5585caf.out`, `rerun_31ada01/SR_regression_compare_31ada01.out`). Fixed-sample optimisations are also bit-for-bit the same on `5585caf` and `31ada01`, although the merge replaced the shortcut.
- On `31ada01`, `R CMD check` runs the examples and the test suite passes apart from 18 plot snapshots in the same two test files that failed on `5585caf` and `gsd-build` on 21 October. Inside the check, 23 tests that compare with gMCPLite were skipped, as it was not installed; run afterwards with gMCPLite 0.1.7, their four files pass (`rerun_31ada01/test_suite_and_check.txt`).

## Running the scripts

Install the `gsd-build-spending` build of multigrain, then for example:

```
Rscript dev/review/stress_test/reprex/A3.R
```

- A script whose header says "Run from the repository root" reads files of the repository by relative path. The others run from anywhere.
- Every script ends with a line starting `EXPECTED:`, which says what a correct package would have done.
- The scripts are kept compact so that each fits on one screen. They carry the comment `# fmt: skip file` so that the repository's formatter (`air`) leaves them as they are.
- Each took under 30 seconds here, most under 10, apart from HS2 (about 3 minutes) and HS9 (about 1 minute), which run optimisations or score 100,000 trials. Most of the rest is the C++ compilation inside `trial_success()` and `trial_success_gsd()`.
- No script ends the session it runs in. Where the error is a crash (A2, A3, B7, D_local_weights), the call is made in a child process and its exit status is printed; 139 is a segmentation fault.
- Some output changes from run to run: values read from memory outside a matrix (A2, A3, MEM4), timings (C17, MEM3), the stack figure in C13 and the number of failed workers (ENV02).
- ENV01 shows its second part only on a machine with a decimal comma locale installed (the output shown used `de_DE.UTF-8`). ENV02 uses forked workers and MEM3 sends a signal with `kill`, so those two are for Linux and macOS.
- The output shown was captured on 18 November 2026 on `31ada01`, in an `en_US.UTF-8` session with R 4.3.3 on Linux (x86_64, g++ 13.3.0, 2 cores), gsDesign 3.11.0 (installed without its table-formatting imports gt and r2rtf, which multigrain never calls), Rcpp 1.0.12, nloptr 2.0.3, GA 3.2.5, mvtnorm 1.2.4, RcppParallel 6.2.1 and rlang 1.3.0, the packages of 21 October (gMCPLite, which only the tests use, was installed after `R CMD check`; see `rerun_31ada01/test_suite_and_check.txt`). On `5585caf` the same setup reproduced every output of the version of 21 October, apart from the run-to-run values above and MEM1, whose script changed; on `31ada01` 75 of the 83 earlier scripts give that output again (`rerun_31ada01/script_comparison.txt`). Nothing here was run on Windows or macOS.

## Potential fixes

- **tested (patch N)**: the change exists in a separate series of 73 commits, written on `gsd-build` before the stopping rule was added (`ee91a11`); 58 of the errors here have one. That series is not part of this branch and has not been rebased onto `8af8adb`, `5585caf` or `31ada01`. N is the position of the commit in the series, and the code shown in the entry is the final state of the series, cut down to the lines that matter. On the series as a whole the test suite passed (658 tests; the only failures were 18 plot snapshots that fail in the same way on `gsd-build` in that environment), `R CMD check` (run without the tests and the vignettes) gave no error or warning, and every script of this folder was rerun on it. Patches that touch files changed by the stopping rule are likely to conflict on a rebase; the entries name the ones known to be affected: 13 (C20), 31 and 61 (DOC4), 55 (C8), 64 and 71 (DOC7). Patch 62 (the pkgdown index) is no longer needed. The fixes of B7 (patch 6), MEM1 (7), MEM3 (12) and the shortcut half of MEM4 (8 and 9) change `src/graph_shortcut.cpp`, which the fast shortcut rewrote (on its branch from 16 October; merged into `main` on 22 October and into `gsd-build-spending` on 4 November). Their changes to that file have to be written again for the new kernel, not rebased: B7's cap goes where `graph_shortcut_parallel()` checks `num_threads`, MEM4's guard into `choose_grain_size()`, MEM3's interrupt checks into both the sequential loop and the table walk, and MEM1's fixed-sample half is no longer needed. Their changes to the group sequential kernel are unaffected. Patches that change `R/calc_power.R` after line 58 meet 9 new lines of help text at line 59 and should rebase with that offset.
- **tested in a scratch build**: SR1, SR2, UT2, UT3 and UT4. The code shown was applied to a copy of `8af8adb`, the script rerun and the full test suite run; it is in no commit. `R/stopping_rule_gsd.R`, which SR1 and SR2 change, is the same on `5585caf`; its test file differs only by a lint comment, which moves its lines down by one. UT2 to UT4 change `R/transform_pvalues_gsd.R`, which `5585caf` extends for spending specs, so those three may need small adjustments there.
- **tested on `e45ee1f`**: HS1 (the print note), HS3, HS5, HS6, HS7 and HS8. The fix was applied to `e45ee1f`, an earlier state of `gsd-build-spending` (15 October), the script of the time rerun and the test suite run; the patch (`hs-fixes.patch`) is not in this repository, and the fixes were not tried on `31ada01`. On `e45ee1f` they made 8 test expectations fail on purpose (5 snapshots of changed messages and labels, and 3 `expect_identical()` checks of HS7's old label); those tests would need updating with the fixes.
- **tested in a session**: ENV08. The function shown was put in place of the package's with `assignInNamespace()` and the script rerun; it was not built into the package, and the test suite was not run with it.
- **suggested, not implemented**: there is no code for it on any branch. Where a suggestion was tried in a throwaway session, the entry says so.
- Several fixes are a judgement call (an error where a warning would also do, a tolerance, a limit). The entry then names the alternative.
- `_pkgdown.yml` and `NEWS.md` were rewritten on `main` after `gsd-build` branched (`aad5556`, `22a9c6e`), and `gsd-build-spending` has now merged `main`. The fix shown for DOC7 applies to `NEWS.md` at `31ada01`; patches 64 and 71 of the series predate both and will conflict.

## Looked at, and not listed as an error

These came up in the same testing. They are design questions or properties to know about, so they have no entry.

- **The optimiser can miss with 4 to 6 hypotheses.** Against an independent optimiser on 28 random problems (20,000 trials each), default runs with 3 hypotheses were within 0.001 of the best known graph every time. With 4 to 6 hypotheses, 10 of 40 runs fell short by more than 0.002, the worst by 0.021 (about 2% of the gain), and two seeds could differ by that much. Running several seeds and keeping the best graph helps today. A possible change: start the local search from the best few candidates of the global stage. Alex's report on the second merge of `main` (`dev/review/hsd_opt/search_quality_report.md`, 5 November) finds the same for the joint spending search: on one design with one spending parameter per hypothesis (H4xi), 29 of 45 runs fell below a gain inside their own search space (on the other such design, H4i, none did), and he gives the same advice.
- **The reported gain is optimistic at small simulation counts.** The graph is optimised and scored on the same simulated trials. With 4 hypotheses the reported gain was above the true one by 0.070 on average at 500 trials, 0.048 at 2,000 and 0.008 at 10,000. Scoring the final graph on fresh p-values with `calc_power_pvals()` removes this.
- **Alpha cannot be discarded.** A complete constraint row must sum to 1, so a terminal node cannot be written as a constraint and the optimiser always recycles. A "sink" hypothesis whose p-values are all 1 and whose weight is fixed at 0 works today and may be worth documenting.
- **Correlation across endpoints with different information fractions.** `simulate_pvalues_gsd()` uses rho times sqrt(min t / max t), as the design record says (section 4.7). That is exact when the fractions index the same subjects. For an event-driven pair such as PFS and OS it is a modelling choice that affects power and the optimal graph, not the error rate. The help could state the assumption.
- **A gain must mention the highest-numbered hypothesis.** A gain written as `r1` is refused for a design with 3 hypotheses; `r1 + 0 * r2 + 0 * r3` is the way round it. Entry C21 covers the one place where this is stricter than it needs to be.
- **The kernels reject on `p < level`, not `p <= level`.** Documented. It differs from gMCPLite and graphicalMCP on exact ties only.

## The stopping rule: what was checked

What was checked, besides SR1 and SR2. The scripts and their output are in [`stopping_rule/`](stopping_rule/); `SR_checks.R` passes 16 of 16 on `8af8adb`, `5585caf` and `31ada01`, and `SR_inputs.R` gives the same output on all three (the outputs on `31ada01` are in [`rerun_31ada01/`](rerun_31ada01/)).

- **The kernel is right.** With no rule, the group sequential kernel agrees exactly with an independent implementation of the graphical procedure, written from its definition (2 to 5 hypotheses, 2 to 4 analyses, random graphs). With a rule, the stopped decision times are exactly the unstopped ones cut at the first interim where the rule holds, for 36 designs and four rules, and so is the stopping look. A list of conditions applies condition k at interim k. The serial and parallel kernels agree to the bit.
- **Error control holds.** Under the global null and under a partial null (200,000 trials, 4 hypotheses, 3 analyses), familywise error was at most 0.0239 with no rule and with three rules.
- **The outputs are consistent.** No local, disjunctive or conjunctive power goes up under any rule; `stop_distribution` sums to 1 and `mean_stop_look` is its mean; power at the first interim is untouched; with no rule, the mass before the last analysis is exactly the trials that rejected everything. With one analysis a rule changes nothing.
- **The optimiser uses the rule.** The gain that `graph_optimise_gsd()` reports equals `calc_power_pvals_gsd()` on the returned graph with the same rule, and the result records the rule and prints it.
- **Nothing changes without a rule.** With no stopping rule, `gsd-build` gives bit-for-bit the same p-values, powers and optimised graphs as before the rule was added (`ee91a11`; `stopping_rule/SR_regression_compare.out`), and `gsd-build-spending` gives the same as `gsd-build` (`stopping_rule/SR_regression_compare_5585caf.out`), at `31ada01` as at `5585caf` (`rerun_31ada01/SR_regression_compare_31ada01.out`).
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

In `NEWS.md` on `31ada01`, from the merge of the fast shortcut:

- The entry says the previous algorithm "is still used for large numbers of hypotheses". It is also used whenever 2^m is more than twice the number of trials (for example 12 hypotheses with fewer than 2,048 trials), and for any graph whose smallest update denominator is below 1e-6. The rejections are the same either way, so this is wording only.
- The same entry has three spaces in "is   no user-visible API change".

## The merged shortcut: what was checked

The fast shortcut was stress tested on its own branch at `62bba6a` on 21 October ([`fast_shortcut_and_family_opt/`](fast_shortcut_and_family_opt/)). Before it was merged, 17 more commits on 22 October, 9 of them to the code or the tests, changed `src/graph_shortcut.cpp` by 489 lines. Two fallbacks were added: a trial whose p-value lies within a relative 1e-6 of a critical value is rerun through the sequential kernel, and a graph whose smallest update denominator is below 1e-6 runs wholly on it. The checks were therefore run again on `31ada01`, where this shortcut scores every fixed-sample graph. Outputs are in [`rerun_31ada01/shortcut/`](rerun_31ada01/shortcut/), with the new script `FS_fallbacks.R`; `FS_kernel.R` and `FS_identity.R` are in `fast_shortcut_and_family_opt/fast-shortcut/`.

- **The 21 October checks pass again.** `FS_kernel.R` passes 9 of 9 on `31ada01`: the table kernel against the sequential kernel on 156 random graphs, 8,528 p-values set at a critical value, graphicalMCP 0.3.0 on 60 graphs, degenerate graphs, the switch between kernels, the largest sizes and the options.
- **Optimisations are unchanged.** `graph_optimise()` with 3, 4, 6 and 8 hypotheses on 1 and 2 threads, and `calc_power_pvals()`, give bit-for-bit the same weights, graphs and powers on `5585caf` and `31ada01` (`FS_identity_compare.out`). The median of five `calc_power_pvals()` calls on 100,000 trials of 12 hypotheses was 0.015 s against 0.036 s (rough timings, 2 shared cores).
- **The new fallbacks hold** (`FS_fallbacks.R`, 6 of 6):
  - FS9: near-degenerate graphs (a pair passing 1 - e to each other, e from 1e-2 to 0), 4 and 8 hypotheses, with p-values placed within 1e-7 of critical values: the table kernel, 2 threads and the sequential kernel agree on all 72 graphs of 3,000 trials. For the graphs whose smallest denominator is below 1e-6, the forced table kernel falls back to the sequential one, so there the check shows only that the fallback leaves the result unchanged; the table kernel itself is exercised down to a denominator of about 1.5e-6 here and in FS11 and FS14.
  - FS10: the smallest denominator the table records leads to the same choice of kernel as an independent enumeration, in R, of every denominator the sequential kernel applies to a non-zero entry (300 graphs, including sparse graphs and graphs with small edges zeroed). The two values differ by at most a relative 3.8e-7, from rounding (R divides, the kernel multiplies by the reciprocal).
  - FS11: 40,680 p-values at a relative 0, 1e-12, 1e-9, 1e-7 and 1e-6 either side of critical values computed in R by removing hypotheses in a random order, on graphs that use the table: no disagreement. The R and table critical values differ by at most a relative 4.6e-11.
  - FS12: familywise error under 12 global and 12 partial nulls (3 to 10 hypotheses, correlation 0, 0.5 and 0.9, 200,000 trials each): at most 0.0247 at 0.025.
  - FS13: the automatic choice switches at 2^m = 2N (6, 10 and 14 hypotheses), with the same rejections either side.
  - FS14: the table kernel against graphicalMCP on 27 near-degenerate graphs that still use the table: no mismatch.
- **Catalogue entries.** MEM1 is narrowed (see its entry). A4, B3_power, B7, C8, C23, MEM3 and MEM4 give the same output; their line references were moved to the new kernel.
- **Not checked:** `dev/docs/shortcut_algorithm.md`, a 418-line explanation of the kernel added with it, was not read against the code.

## Other branches

Four newer branches start from `main`. Two of them were stress tested on 21 October, in [`fast_shortcut_and_family_opt/`](fast_shortcut_and_family_opt/); the other two on 18 November, in [`split_merge_and_vignette/`](split_merge_and_vignette/). Each folder has its own README.

- `fast-shortcut`: merged into `main` (PR #48, `c17b75a`) and into `gsd-build-spending`. See "The merged shortcut: what was checked" above.
- `family-opt` (`851f58e`, PR #46): unchanged since 21 October. Its five findings stand and are kept in that folder: FAM1 (severity 2) is a missing p-value inside a family; A4 (severity 1) and MEM1 (severity 2) reach the families code; FAM3 (severity 3) widens C20; FAM2 (severity 4) is about node labels.
- `split-merge` (`ff9d907`, PR #53): replaces the mutation of the genetic algorithm in `graph_optimise()`. The new mutation is sound, and on three problems it found graphs 0.0006 to 0.0018 better on fresh trials, more repeatably, in 1.5 to 3.2 times the time. Merging the branch into `gsd-build-spending` would stop `graph_optimise_gsd()` whenever the global search runs, its default, with "could not find function \".make_cauchy_mutation_multi\"". Git reports conflicts only in `.gitignore` and `NEWS.md`, so nothing at merge time would show it (SM1 in that folder). B2 still holds there.
- `trial_success_vignette` (`b1c9f21`, PR #54): a rewrite of the trial success article for `main`. Its code runs on the branch and on `main`, with the same output apart from compile messages. It sets the old verbosity option, so once `main` is merged into it the article prints 14 compile messages (ENV08). It merges into `main` cleanly; merging it into `gsd-build-spending` conflicts in three files, two of them the article and its committed Quarto intermediate (UT5).

## Not tested

- Windows and macOS.
- A p-value matrix above 2^31 elements (entry MEM1 was established by reading the code and by arithmetic; the machine had too little memory to run it).
- The branches `sample-size-pub` and `plan-for-sparsity`, beyond reading how they would merge.
- The stopping rule on a real design (a confidential GSK design was not used here), and with spending functions other than O'Brien-Fleming type.
- The fix series on `gsd-build` or `gsd-build-spending`: it was written before the stopping rule and has not been rebased (it is not in this repository).
- The statistical checks of the joint spending search of 15 October (resolved p-values against the fixed transform, boundaries against gsDesign, familywise error in 6,000 designs, a brute-force search at every node) were not rerun; their scripts are not in this repository. The spending code is the same on `5585caf` and `31ada01`, and Alex's report on the merge (`dev/review/hsd_opt/search_quality_report.md`) found the spending search bit-for-bit the same before and after it. HS1 to HS10 were rechecked with new scripts.
- The fixes of the HS entries on `31ada01` (they were tried on `e45ee1f`), and ENV08's fix in a build.
- `dev/docs/shortcut_algorithm.md` against the code it explains.

## Changes from earlier versions

### This version: rerun on `gsd-build-spending` at `31ada01` (18 November 2026)

The third version (21 October 2026, commit `7adbbad`, on the fork's branch `stress-test-errors`) described `gsd-build-spending` at `5585caf`. On 4 November that branch merged `main` again (`e103474`), bringing the merged fast shortcut and the renamed verbosity option, and added a report on the spending search (`31ada01`). For this version the catalogue was moved onto `31ada01` on a new branch, `stress-test-errors-31ada01`, and every earlier script was run on `5585caf`, `31ada01` and `main` (`508d0b7`); the HS scripts were run on `31ada01` only. [`rerun_31ada01/script_comparison.txt`](rerun_31ada01/script_comparison.txt) compares them script by script.

- **Added:**
  - HS1 to HS10, the findings of the stress test of the joint spending search (15 October, on `e45ee1f`). Each was rechecked on `31ada01` with a new script and still holds. Their line references are at `31ada01`.
  - ENV08: the verbosity option was renamed on `main`, and the old name is now ignored without a message.
- **Narrowed:** MEM1. The fast shortcut gave the fixed-sample kernel 64-bit offsets, so on `main` and `31ada01` only the group sequential kernel is affected. Multigrain 1.0.0 on CRAN still has the fixed-sample case. The script now reads the group sequential kernel, and "On `main`" is now no.
- **Output changed:** DOC7 (the development section of `NEWS.md` gained a "Changes" heading, and "Bug fixes" became "Minor improvements and bug fixes"; the three missing names are still missing) and DOC16 (version number only). DOC16's text now counts 23 unlisted words, since the merge removed `arXiv` from the word list.
- **Line references moved:** every reference to `src/graph_shortcut.cpp` (A4, B3_power, B7, C8, C23, MEM1, MEM3 and MEM4), the 14 references to `R/calc_power.R` after line 58 (in 10 entries; 9 lines of help were added at line 59), the 3 references to `DESCRIPTION` (DOC16, D_graphics_undeclared, D_ggplot2_optional) and the development section of `NEWS.md` (DOC7). Every other reference points at a line that did not move.
- **Checks:** `R CMD check` and the test suite on `31ada01` (`rerun_31ada01/test_suite_and_check.txt`); the stopping-rule checks (16 of 16 pass; with no rule `31ada01` matches `5585caf` bit for bit); the merged shortcut ("The merged shortcut: what was checked"); and the new branches `split-merge` and `trial_success_vignette` ([`split_merge_and_vignette/`](split_merge_and_vignette/)).
- Every other entry gives the same output on `31ada01` as on `5585caf`, apart from the run-to-run values listed under "Running the scripts". On `main`, every entry marked "yes" still shows its error; where its output differs from `31ada01`, it is in run-to-run values, a line number, or lines about group sequential functions, files or articles (`script_comparison.txt` notes each).

### Third version: rerun on `gsd-build-spending` (21 October 2026)

The second version (14 October 2026, commit `5ff1ee8`) described `gsd-build` at `8af8adb`. For the third version the commit was moved onto `gsd-build-spending` at `5585caf`, and every script was rerun on both builds. [`rerun_5585caf/script_comparison.txt`](rerun_5585caf/script_comparison.txt) compares them script by script.

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
