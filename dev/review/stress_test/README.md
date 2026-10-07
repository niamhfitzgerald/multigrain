# Stress test of `gsd-build`: the errors, one by one

Niamh Fitzgerald, October 2026. Commit tested: `ee91a11` on `gsd-build`.

This folder lists the errors found in two rounds of stress testing of multigrain. Each entry has the same four parts:

1. **What the error is**: what a user does and what happens.
2. **What causes it**: the mechanism, with file and line at `ee91a11`.
3. **Code showing the problem**: a short script, followed by the output it gave. The same script is in `reprex/`.
4. **Potential fix**: a short code change, and what it does.

This branch changes no package code. It adds this folder and nothing else, so every script shows its problem when run against `gsd-build` as it stands.

## Files

| File | Contents | Entries |
|---|---|---|
| [`1_wrong_results_or_crashes.md`](1_wrong_results_or_crashes.md) | Severity 1: a wrong number or a crash, with no warning | 7 |
| [`2_misleading_or_broken_contract.md`](2_misleading_or_broken_contract.md) | Severity 2: misleading in plausible use, or a result that breaks its own contract | 15 |
| [`3_validation_and_messages.md`](3_validation_and_messages.md) | Severity 3: missing or wrong input validation, and messages that point the wrong way | 32 |
| [`4_documentation_and_housekeeping.md`](4_documentation_and_housekeeping.md) | Severity 4: documentation, printing, housekeeping, and internal routines no user reaches | 23 |
| `reprex/<ID>.R` | The short script of each entry | 77 |

## IDs

The IDs are those of the two stress-test reports: A, B, C and D from round 1 (most to least serious), ST, ENV, MEM, DOC and REG from round 2 (statistics, environment, memory, documentation, comparison with `main`). Findings that turned out to be one defect share an entry: B7 with MEM2, B8 with DOC5, B9 with ENV06, C1 with ST2, C19 with MEM5, DOC13 with ENV07, and DOC17e inside B3_simulators. B3 and ENV03 each have two entries, one per group of functions.

## Summary

- 77 entries. 7 of them give a wrong number or end the R session with no warning: A1 to A5, ST1 and ENV01.
- 57 of the 77 are also on `main`. The fixed-sample code is the same on the two branches, so those can be fixed on either. This was checked at `324b7ca` (15 September 2026), mostly by running the script on a build of it. `main` has since moved to `856eb0d` (6 October 2026); the commits in between change help text, the site index, NEWS, the word list and the version number, and no code in `R/` or `src/` outside comments.
- 60 entries have a tested fix and 17 a suggested one (see "Potential fixes" below).
- Outside these entries the statistics held up. Familywise error, the rejection thresholds, the look-back rule and power agreed with independent references. The last section of this page lists what was looked at and is not an error.

## Running the scripts

Install the `gsd-build` build of multigrain, then for example:

```
Rscript dev/review/stress_test/reprex/A3.R
```

- A script whose header says "Run from the repository root" reads files of the repository by relative path. The others run from anywhere.
- Every script ends with a line starting `EXPECTED:`, which says what a correct package would have done.
- The scripts are kept compact so that each fits on one screen. They carry the comment `# fmt: skip file` so that the repository's formatter (`air`) leaves them as they are.
- Each takes under 20 seconds on a quiet machine. Most of that is the C++ compilation inside `trial_success()` and `trial_success_gsd()`.
- No script ends the session it runs in. Where the error is a crash (A2, A3, B7, D_local_weights), the call is made in a child process and its exit status is printed; 139 is a segmentation fault.
- Some output changes from run to run: values read from memory outside a matrix (A2, A3, MEM4), timings (C17, MEM3), the stack figure in C13 and the number of failed workers (ENV02).
- ENV01 shows its second part only on a machine with a decimal comma locale installed (the output shown used `de_DE.UTF-8`). ENV02 uses forked workers and MEM3 sends a signal with `kill`, so those two are for Linux and macOS. REG3 calls `git` and needs the tag `v0.3.0`.
- The output shown was captured with R 4.3.3 on Linux (x86_64, g++ 13.3.0, 2 cores), gsDesign 3.11.0, Rcpp 1.0.12, RcppParallel 6.2.1, nloptr 2.0.3, GA 3.2.5 and mvtnorm 1.2.4. Nothing here was run on Windows or macOS.

## Potential fixes

- **tested (patch N)**: the change exists in a separate series of 73 commits on top of `ee91a11`, 60 of which carry a regression test. That series is not part of this branch. N is the position of the commit in the series, and the code shown in the entry is the final state of the series, cut down to the lines that matter. On the series as a whole the test suite passes (658 tests; the only failures are 18 plot snapshots that fail in the same way on `gsd-build` in that environment), `R CMD check` (run without the tests and the vignettes) gives no error or warning, and every script of this folder was rerun on it. The series can be sent as patches or opened as a pull request of its own.
- **suggested, not implemented**: there is no code for it on any branch. Where a suggestion was tried in a throwaway session, the entry says so.
- Several fixes are a judgement call (an error where a warning would also do, a tolerance, a limit). The entry then names the alternative.
- `_pkgdown.yml` and `NEWS.md` were rewritten on `main` after `gsd-build` branched (`aad5556`, `22a9c6e`). The fixes shown for DOC3 and DOC7 are written against `gsd-build` and will need redoing once `main` is merged in.

## Index

77 entries. "On `main`" says whether the error is also on `main`; the group sequential functions exist on `gsd-build` only.

| ID | Sev. | Error | Functions | On `main` | Potential fix |
|---|---|---|---|---|---|
| [A1](1_wrong_results_or_crashes.md#A1) | 1 | A gain that is negative for every graph is not optimised | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 46, 67 |
| [A2](1_wrong_results_or_crashes.md#A2) | 1 | A gain written for more hypotheses than the p-values have is evaluated outside the rejection matrix | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patches 1, 2, 68 |
| [A3](1_wrong_results_or_crashes.md#A3) | 1 | Index 0 is accepted in a gain and reads outside the matrix | trial_success(), trial_success_gsd() | yes | tested, patch 30 |
| [A4](1_wrong_results_or_crashes.md#A4) | 1 | sum_to_one_constraint = FALSE switches off the row-sum check, so a graph can hand out alpha twice | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 3 |
| [A5](1_wrong_results_or_crashes.md#A5) | 1 | An information fraction above 1 with an uncapped spending function spends more than alpha | transform_pvalues_gsd() | no | tested, patches 19, 65, 70 |
| [ST1](1_wrong_results_or_crashes.md#ST1) | 1 | A flat stretch of the boundary table is inverted from its lower end, so a hypothesis is rejected with nothing left to spend | transform_pvalues_gsd() | no | tested, patch 18 |
| [ENV01](1_wrong_results_or_crashes.md#ENV01) | 1 | A decimal comma in the session changes the gain that is compiled, with no message | trial_success(); trial_success_gsd() fails with an unrelated error | yes | tested, patches 28, 29 |
| [B1](2_misleading_or_broken_contract.md#B1) | 2 | start_graph is ignored when global_search = FALSE | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 47, 70, 73 |
| [B2](2_misleading_or_broken_contract.md#B2) | 2 | A fixed constraint value below 0.001 is not kept | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 49 |
| [B3_power](2_misleading_or_broken_contract.md#B3_power) | 2 | calc_power_pvals() accepts missing and out-of-range p-values and any alpha | calc_power_pvals(), graph_optimise() | yes | tested, patches 4, 59 |
| [B3_simulators](2_misleading_or_broken_contract.md#B3_simulators) | 2 | The simulators do not validate power_nominal, and simulate_pvalues() does not validate nsim | simulate_pvalues(), simulate_pvalues_gsd() | yes | tested, patch 26 |
| [B4](2_misleading_or_broken_contract.md#B4) | 2 | The simulators accept matrices that are not correlation matrices | simulate_pvalues(), simulate_pvalues_gsd() | yes | tested, patch 25 |
| [B5](2_misleading_or_broken_contract.md#B5) | 2 | A string objective of trial_success() is written into C++ unchecked | trial_success(), trial_success_gsd() | yes | tested, patches 32, 33, 34, 68, 70 |
| [B6](2_misleading_or_broken_contract.md#B6) | 2 | The returned graph can be worse than the graph the search started from | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 48, 69 |
| [B7](2_misleading_or_broken_contract.md#B7) | 2 | A num_threads of 65,537 or more ends the R session | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 6 |
| [B8](2_misleading_or_broken_contract.md#B8) | 2 | The help page of trial_success() is malformed and its examples do not parse, so R CMD check fails | trial_success() (help page; one argument description is inherited by trial_success_gsd()) | no | tested, patches 31, 61 |
| [B9](2_misleading_or_broken_contract.md#B9) | 2 | A gain, and any saved optimisation result, cannot be used after it is reloaded | trial_success(), trial_success_gsd(), calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd() | yes | tested, patches 36, 60, 68 |
| [ENV02](2_misleading_or_broken_contract.md#ENV02) | 2 | Gains built at the same moment in forked workers fail at random | trial_success(), trial_success_gsd() | yes | tested, patch 35 |
| [ENV03_power](2_misleading_or_broken_contract.md#ENV03_power) | 2 | Hypothesis names are ignored, so a graph named in another order is evaluated as a different graph | calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid(), graph_optimise(), graph_optimise_gsd() | yes | tested, patches 5, 66 |
| [ENV03_spending](2_misleading_or_broken_contract.md#ENV03_spending) | 2 | A spending list named in another order is applied by position, and summary() prints its names in the wrong rows | transform_pvalues_gsd() | no | tested, patches 22, 70 |
| [ENV04](2_misleading_or_broken_contract.md#ENV04) | 2 | A local search on all rows depends on the session seed, and changes it | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 50 |
| [MEM1](2_misleading_or_broken_contract.md#MEM1) | 2 | The serial kernels compute matrix offsets in 32-bit integers, which overflow above 2^31 p-values | calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise() and graph_optimise_gsd() with num_threads = 1 | yes | tested, patch 7 |
| [C1](3_validation_and_messages.md#C1) | 3 | An analysis that spends nothing aborts the whole transform, with advice that cannot help | transform_pvalues_gsd() | no | tested, patch 20 |
| [C2](3_validation_and_messages.md#C2) | 3 | Two analyses with nearly the same information abort with a message that blames the spending function | transform_pvalues_gsd() | no | tested, patches 24, 65, 70, 72 |
| [C3](3_validation_and_messages.md#C3) | 3 | A missing p-value at a single full-information analysis stays NA, and the power function then blames the caller | transform_pvalues_gsd(), calc_power_pvals_gsd() | no | tested, patch 21 |
| [C4](3_validation_and_messages.md#C4) | 3 | grid_size is accepted down to 2, where the type I error is above the level | transform_pvalues_gsd() | no | suggested |
| [C5](3_validation_and_messages.md#C5) | 3 | First-analysis repeated p-values are wrong for raw p-values below about 1e-15 | transform_pvalues_gsd() | no | suggested |
| [C6](3_validation_and_messages.md#C6) | 3 | An error inside a spending function or gsBound1() surfaces without the hypothesis it belongs to | transform_pvalues_gsd() | no | tested, patch 23 |
| [C7](3_validation_and_messages.md#C7) | 3 | The tolerance of a graph constraint is not carried into the optimiser | graph_constraint(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 54 |
| [C8](3_validation_and_messages.md#C8) | 3 | A constraint of the wrong size is reported by base R or by the C++ kernel | graph_constraint(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 55 |
| [C9](3_validation_and_messages.md#C9) | 3 | Hypothesis names are not validated, and plot() fails after the optimisation | graph_constraint(), graph_constraint_free(), graph_random(), plot() | yes | tested, patches 56, 66 |
| [C10](3_validation_and_messages.md#C10) | 3 | start_graph is checked for type and size only | graph_optimise(), graph_optimise_gsd() | yes | tested, patches 51, 66 |
| [C11](3_validation_and_messages.md#C11) | 3 | Options of the local search are not checked, and a misspelt one is dropped in silence | control_local(), graph_optimise(), graph_optimise_gsd(), print() of a result | yes | tested, patch 52 |
| [C12](3_validation_and_messages.md#C12) | 3 | control_global() can replace the objective, the bounds and the start graphs of the global search | control_global(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 53 |
| [C13](3_validation_and_messages.md#C13) | 3 | A flat sum of a few hundred terms cannot be turned into a gain: the C stack runs out | trial_success(), trial_success_gsd() | yes | suggested |
| [C14](3_validation_and_messages.md#C14) | 3 | trial_success_gsd() cannot compile a sign applied to a signed value | trial_success_gsd() | no | tested, patch 37 |
| [C15](3_validation_and_messages.md#C15) | 3 | trial_success() fails in the C++ compiler on a value taken from a named vector | trial_success() | yes | tested, patches 29, 39 |
| [C16](3_validation_and_messages.md#C16) | 3 | trial_success() cannot build a gain with a constant that R prints in exponent form (100000, 0.0001) or with a negative constant | trial_success() | yes | tested, patches 28, 38 |
| [C17](3_validation_and_messages.md#C17) | 3 | A mistyped hypothesis index is accepted, however large | trial_success(), trial_success_gsd() | yes | tested, patch 41 |
| [C18](3_validation_and_messages.md#C18) | 3 | A discount table that the gain never applies is accepted without a word | trial_success_gsd() | no | tested, patch 42 |
| [C19](3_validation_and_messages.md#C19) | 3 | Every gain keeps a shared library loaded and build files on disk until the session ends | trial_success(), trial_success_gsd() | yes | suggested |
| [C20](3_validation_and_messages.md#C20) | 3 | A custom_power entry named like a built-in output field is hidden behind it | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 13 |
| [C21](3_validation_and_messages.md#C21) | 3 | calc_power_pvals_gsd() refuses a gain that does not mention the last hypothesis | calc_power_pvals_gsd() | no | suggested |
| [C22](3_validation_and_messages.md#C22) | 3 | is_graph_valid() stops on a missing value, and normalise_sum() keeps negative weights | is_graph_valid(), normalise_sum(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patches 10, 11 |
| [C23](3_validation_and_messages.md#C23) | 3 | An epsilon edge below about 1e-13 gives wrong local levels | calc_power_pvals(), calc_power_pvals_gsd(), is_graph_valid() | yes | suggested |
| [ENV05](3_validation_and_messages.md#ENV05) | 3 | With a negative scipen option, or a deleted working directory, no gain can be built | trial_success(), trial_success_gsd() | yes | tested, patches 28, 43, 44 |
| [MEM3](3_validation_and_messages.md#MEM3) | 3 | A kernel call cannot be interrupted | calc_power_pvals(), calc_power_pvals_gsd(), graph_optimise(), graph_optimise_gsd() | yes | tested, patch 12 |
| [DOC12](3_validation_and_messages.md#DOC12) | 3 | The error for `r1 + r2 && r3` does not say that parentheses are needed | trial_success_gsd() | no | tested, patch 40 |
| [DOC14](3_validation_and_messages.md#DOC14) | 3 | Replacing any other element of a graph constraint gives "object 'output' not found" | graph_constraint() (the replacement methods `$<-`, `[[<-` and `[<-` of its objects) | yes | tested, patch 57 |
| [DOC17b](3_validation_and_messages.md#DOC17b) | 3 | Integer weights are refused although hyp_weight is documented as numeric | calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 14 |
| [DOC17c](3_validation_and_messages.md#DOC17c) | 3 | normalise_sum() accepts a negative tolerance | normalise_sum() | yes | tested, patch 11 |
| [DOC17d](3_validation_and_messages.md#DOC17d) | 3 | normalise_sum() does not check fixed_idx against the length of x | normalise_sum() | yes | tested, patch 11 |
| [DOC17f](3_validation_and_messages.md#DOC17f) | 3 | plot(x, root = 7) on a graph with 4 hypotheses gives a raw igraph error | plot() and autoplot() of a result and of a graph constraint | yes | suggested |
| [DOC17g](3_validation_and_messages.md#DOC17g) | 3 | sum_to_one_constraint = NA gives R's own error, not a message about the argument | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() | yes | tested, patch 10 |
| [MEM4](4_documentation_and_housekeeping.md#MEM4) | 4 | Two internal routines lack a guard: an out-of-bounds read and a division by zero | none exported (internal graph_violation_score_cpp(), graph_shortcut_parallel(), graph_shortcut_gsd_parallel()) | yes | tested, patches 8, 9 |
| [D_ggplot2_optional](4_documentation_and_housekeeping.md#D_ggplot2_optional) | 4 | The plot help calls ggplot2 an optional dependency, but the package cannot be loaded without it | plot() and autoplot() for graph constraints and optimised graphs | yes | suggested |
| [D_global_output](4_documentation_and_housekeeping.md#D_global_output) | 4 | result$global_output is an invalid S4 object and cannot be printed | graph_optimise(), graph_optimise_gsd() | yes | tested, patch 58 |
| [D_graphics_undeclared](4_documentation_and_housekeeping.md#D_graphics_undeclared) | 4 | The namespace imports plot from graphics, which DESCRIPTION does not declare | plot() for graph constraints and optimised graphs | yes | suggested |
| [D_local_weights](4_documentation_and_housekeeping.md#D_local_weights) | 4 | The unused internal calc_local_weights() crashes for zero hypotheses and reads past a matrix that is too small | none exported (internal calc_local_weights()) | yes | suggested |
| [D_plot_rounding](4_documentation_and_housekeeping.md#D_plot_rounding) | 4 | From 5 hypotheses up, plot() labels an edge of 0.001 as 0 | plot() and autoplot() of a result and of a graph constraint, print() of a result | yes | suggested |
| [D_power_nominal](4_documentation_and_housekeeping.md#D_power_nominal) | 4 | The help calls power_nominal the power "at its final analysis"; it is the power at an information fraction of 1 | simulate_pvalues_gsd() | no | tested, patch 27 |
| [DOC1](4_documentation_and_housekeeping.md#DOC1) | 4 | The get-started article codes "both primaries" where its text and formula say "at least one" | trial_success() (as used in the get-started article and in data-raw/) | yes | suggested |
| [DOC2](4_documentation_and_housekeeping.md#DOC2) | 4 | The results printed in the get-started article are stored objects in an old layout | graph_optimise(), graph_optimal_get_control() and summary() of an optimised graph (as shown in the get-started article) | yes | suggested |
| [DOC3](4_documentation_and_housekeeping.md#DOC3) | 4 | The pkgdown site does not build: four group sequential help topics are missing from the reference index | calc_power_pvals_gsd(), graph_optimise_gsd(), graph_optimize_gsd(), simulate_pvalues_gsd(), transform_pvalues_gsd() | no | tested, patch 62 |
| [DOC4](4_documentation_and_housekeeping.md#DOC4) | 4 | A sentence of ?trial_success is cut off after "60" | trial_success() (help page) | no | tested, patches 31, 61 |
| [DOC6](4_documentation_and_housekeeping.md#DOC6) | 4 | A roxygen-style link in the trial success article is shown as literal brackets | trial_success() (article "Trial success measures") | no | tested, patch 63 |
| [DOC7](4_documentation_and_housekeeping.md#DOC7) | 4 | NEWS.md announces neither the group sequential functions nor the new gsDesign dependency | simulate_pvalues_gsd(), transform_pvalues_gsd(), trial_success_gsd(), graph_optimise_gsd(), graph_optimize_gsd(), calc_power_pvals_gsd() | no | tested, patches 64, 71 |
| [DOC8](4_documentation_and_housekeeping.md#DOC8) | 4 | The script in data-raw no longer rebuilds the bundled dataset | graph_optimal_example (dataset), graph_optimise() | yes | suggested |
| [DOC9](4_documentation_and_housekeeping.md#DOC9) | 4 | A development vignette documents optimize_N(), which was removed, and its data file sits with the published articles | none exported (optimise_N() and optimize_N() were removed in version 0.2.0) | yes | suggested |
| [DOC10](4_documentation_and_housekeeping.md#DOC10) | 4 | The help example of calc_power_pvals() calls a sum of rejections "average_power" | calc_power_pvals() (help page) | yes | tested, patch 15 |
| [DOC11](4_documentation_and_housekeeping.md#DOC11) | 4 | The help text of sum_to_one_constraint reads as the opposite of what the argument does | is_graph_valid(), calc_power_pvals(), calc_power_pvals_gsd() (help pages) | yes | tested, patch 16 |
| [DOC13](4_documentation_and_housekeeping.md#DOC13) | 4 | Nothing a user reads says that defining a gain needs a C++ toolchain every time | trial_success(), trial_success_gsd() | yes | tested, patch 45 |
| [DOC15](4_documentation_and_housekeeping.md#DOC15) | 4 | The get-started article has a dead link to the graph constraint article and a chunk with two labels | graph_constraint() (get-started article) | yes | tested, patch 63 |
| [DOC16](4_documentation_and_housekeeping.md#DOC16) | 4 | Package metadata is out of step: two unused website dependencies, a release version under a development heading, an incomplete word list | none (DESCRIPTION, NEWS.md, inst/WORDLIST) | yes | suggested |
| [DOC17a](4_documentation_and_housekeeping.md#DOC17a) | 4 | The result name of a single custom_power measure is not documented | calc_power_pvals(), calc_power_pvals_gsd() (help pages) | yes | tested, patch 17 |
| [DOC17h](4_documentation_and_housekeeping.md#DOC17h) | 4 | The graph constraint article calls the argument for the number of hypotheses `m`; it is `num_hyp` | graph_constraint_free() | yes | tested, patch 63 |
| [REG3](4_documentation_and_housekeeping.md#REG3) | 4 | gsd-build still reports version 0.3.0, the number of the tag, yet gives different results for the same seed | graph_optimise() (through packageVersion("multigrain")) | no | suggested |

## Looked at, and not listed as an error

These came up in the same testing. They are design questions or properties to know about, so they have no entry.

- **The optimiser can miss with 4 to 6 hypotheses.** Against an independent optimiser on 28 random problems (20,000 trials each), default runs with 3 hypotheses were within 0.001 of the best known graph every time. With 4 to 6 hypotheses, 10 of 40 runs fell short by more than 0.002, the worst by 0.021 (about 2% of the gain), and two seeds could differ by that much. Running several seeds and keeping the best graph helps today. A possible change: start the local search from the best few candidates of the global stage.
- **The reported gain is optimistic at small simulation counts.** The graph is optimised and scored on the same simulated trials. With 4 hypotheses the reported gain was above the true one by 0.070 on average at 500 trials, 0.048 at 2,000 and 0.008 at 10,000. Scoring the final graph on fresh p-values with `calc_power_pvals()` removes this.
- **Alpha cannot be discarded.** A complete constraint row must sum to 1, so a terminal node cannot be written as a constraint and the optimiser always recycles. A "sink" hypothesis whose p-values are all 1 and whose weight is fixed at 0 works today and may be worth documenting.
- **Correlation across endpoints with different information fractions.** `simulate_pvalues_gsd()` uses rho times sqrt(min t / max t), as the design record says (section 4.7). That is exact when the fractions index the same subjects. For an event-driven pair such as PFS and OS it is a modelling choice that affects power and the optimal graph, not the error rate. The help could state the assumption.
- **A gain must mention the highest-numbered hypothesis.** A gain written as `r1` is refused for a design with 3 hypotheses; `r1 + 0 * r2 + 0 * r3` is the way round it. Entry C21 covers the one place where this is stricter than it needs to be.
- **The kernels reject on `p < level`, not `p <= level`.** Documented. It differs from gMCPLite and graphicalMCP on exact ties only.

## Small items without an entry

Of the same kind as entry C22, and too small for an entry each. On `gsd-build`:

- `normalise_sum(c(Inf, 1))` and `normalise_sum(c(NA, 1))` stop with R's own "missing value where TRUE/FALSE needed".
- `is_graph_valid()` given a list as `hyp_weight` stops with "invalid 'type' (list) of argument".

## Not tested

- Windows and macOS.
- A p-value matrix above 2^31 elements (entry MEM1 was established by reading the code and by arithmetic; the machine had too little memory to run it).
- The branches `sample-size-pub` and `plan-for-sparsity`, beyond reading how they would merge.
