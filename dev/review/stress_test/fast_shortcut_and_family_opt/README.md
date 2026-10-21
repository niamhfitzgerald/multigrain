# Stress test of `fast-shortcut` and `family-opt`

Niamh Fitzgerald, 21 October 2026. Nothing here has been pushed.

| Branch | Commit | What it adds |
|---|---|---|
| `fast-shortcut` | `62bba6a` (20 October) | A faster kernel for the graphical shortcut: the critical values of every intersection are computed once per graph, then looked up in each trial |
| `family-opt` | `851f58e` (19 October) | `family_spec()` and a `families` argument: graphs whose nodes are families of hypotheses (Maurer and Bretz, 2014), with Hommel, Hochberg or Holm within each family |
| `main` (baseline) | `16f66d0` | Version 1.0.0.9000: the development version after the 1.0.0 CRAN submission (`7884824`), with the same code. Both branches start from it |

Neither branch has the group sequential functions, so this covers the fixed-sample code only.

## In one minute

- **`fast-shortcut` is sound.** The new kernel gave the same rejections as the old one in every check, including 8,528 p-values set exactly at a critical value. It also matched graphicalMCP. Whole optimisations are bit-for-bit the same as on `main`. It is 1.5 to 2.3 times faster for 8 to 12 hypotheses. No new errors, and MEM1 is narrowed.
- **`family-opt` is sound in normal use.** The kernel matched an independent version of the procedure, error control held in 51 designs, and invalid specifications are refused with clear messages. Without `families`, weights, graphs and powers are bit-for-bit the same as on `main`.
- **Five findings on `family-opt`:**
  - **FAM1 (severity 2):** a missing p-value inside a family is accepted. It changes the other members' adjusted p-values, and with Hommel or Hochberg the hypothesis with no p-value can be rejected.
  - **A4 reaches the families path (severity 1):** `sum_to_one_constraint = FALSE` lets a family pass its weight on twice (error rate 0.0497 at 0.025).
  - **MEM1 widened (severity 2):** the new families code uses the same 32-bit offsets, and with families even multi-threaded runs reach them.
  - **FAM3 (severity 3):** the C20 name clash now covers `family_power`.
  - **FAM2 (severity 4):** graph nodes are labelled H1, H2, ... although each node is a family, unless the user names the constraint's nodes.
- **The catalogue:** 58 of its 83 scripts run on these builds. Of the others, 20 need group sequential functions and 5 read files that only the group sequential branches have. All 58 give the same output on both branches as on `main`, apart from run-to-run values and MEM1 on `fast-shortcut`. There, MEM1 is narrowed: the new kernel uses 64-bit offsets, but the old kernel still uses 32-bit ones.
- **`R CMD check` and the tests:** the same on all three builds. The examples run, and the only failures are 18 plot snapshots that fail here with older plotting packages.

## `fast-shortcut`

### Checks

Script `fast-shortcut/FS_kernel.R`, output `FS_kernel.out`: 9 of 9 pass (FS7 counts as two checks).

| ID | Check | Result |
|---|---|---|
| FS1 | Old kernel (serial) against the new kernel (serial and 2 threads) on 156 random graphs (2 to 14 hypotheses, full and partial row sums, sparse graphs), 1,500 trials each | identical |
| FS2 | p-values rounded to 4 decimals, as from a trial report, with equal weights 1/m (3 to 8 hypotheses) or random weights rounded to 2 decimals: 300 cases of 400 trials | identical |
| FS3 | A p-value set exactly at the new kernel's critical value for a set reached after other rejections: 8,528 probes | identical |
| FS4 | New kernel against `graphicalMCP::graph_test_shortcut()`: 60 graphs, 50 trials each | identical |
| FS5 | Degenerate graphs (g12 = g21 = 1), zero weights, edges of 1e-15, p = 0, p = 1, missing p-values, exact ties | identical |
| FS6 | The kernel depends on the number of trials (12 hypotheses: old kernel for 100 trials, new for 20,000); the same rows give the same rejections | identical |
| FS7 | 20 hypotheses: table of 2^20 rows (160 MB) built in 0.9 s; forcing the new kernel at 21 hypotheses gives a clear error | as the source comments describe (the limit and the options are not in the help) |
| FS8 | Invalid values of the two internal options | all refused, with clear messages |

Script `FS_identity.R`, run on both builds, output `FS_identity_compare.out`:

- `graph_optimise()` with 3, 4, 6 and 8 hypotheses, serial and 2 threads, and `calc_power_pvals()`: bit-for-bit the same as on `main`.
- One `calc_power_pvals()` call on 100,000 trials: 1.1 times faster for 4 hypotheses, 1.5 times for 8 and 2.3 times for 12. These were measured while other jobs ran, so treat them as rough.

### Catalogue entries on this branch

- **MEM1, narrowed.** The new kernel walks the trials with 64-bit offsets (`std::size_t`, `src/graph_shortcut.cpp:294-320`). The old kernel still declares `int N` and `int set` (`src/graph_shortcut.cpp:372, 410-428`), and it is the one used for more than 20 hypotheses, as in MEM1's example of 22. Three of the four lines the MEM1 script prints are now the new kernel's, since they come first in the file.
- **MEM3, still present.** A call still cannot be interrupted.
- Every other script that runs gives the same output as on `main`.

### Smaller points

- `NEWS.md` says the old algorithm "is still used for large numbers of hypotheses". It is also used whenever 2^m is more than twice the number of trials, for example 12 hypotheses with fewer than 2,048 trials. The rejections are the same, so this is wording only.

## `family-opt`

### Checks

Script `family-opt/FA_families.R`, output `FA_families.out`: 7 of 10 pass. The three that fail are findings FAM1, A4 and FAM3 below.

| ID | Check | Result |
|---|---|---|
| FA1 | The kernel against an independent version written from the help page: 120 random cases (2 to 9 hypotheses, 1 to 5 families, mixed tests), 200 trials each, with rounded p-values and equal p-values within a family | identical |
| FA2 | Familywise error under the global null, 200,000 trials: 3 family layouts, correlation 0, 0.5 and 0.9 within families (half that between families), each test (27 designs) | at most 0.0248 at 0.025 |
| FA3 | Familywise error under partial nulls: 24 random designs, 100,000 trials each | none above 0.025 |
| FA4 | One family, correlation -0.9 (the help says to use Holm) | 0.0251 for all three tests, within simulation error |
| FA5 | A missing p-value inside a family | **accepted silently** (FAM1) |
| FA6 | 12 invalid specifications (duplicates, gaps, 0, NA, 1.5, empty families, strings, duplicate names, a misspelt test, wrong length) | all refused, with clear messages |
| FA7 | The families path with `sum_to_one_constraint = FALSE` | **0.0497 at 0.025** (A4) |
| FA8 | A `custom_power` entry named `family_power` | **hidden** (FAM3) |
| FA9 | `graph_optimise()` with families: the reported gain equals `calc_power_pvals()` on the returned graph; `print()` and `plot()` work | pass |
| FA10 | Families of 30 and 10 hypotheses, 20,000 trials | 0.13 s |

Also checked:

- Sizes that do not match are refused with clear messages: a graph with one node per hypothesis, families covering more hypotheses than the p-values, families given as a plain list (`FA_families.out`, under FA7).
- Without `families`, `graph_optimise()` (3, 4, 6 and 8 hypotheses, serial and 2 threads) and `calc_power_pvals()` give bit-for-bit the same weights, graphs and powers as on `main` (`FA_identity_compare.out`). The `graph_optimise()` result has one new field, `families` (`NULL` here), placed before `power`, so code that indexes the result by position would shift.

### Findings

Each has a script in `family-opt/reprex/`, with its output next to it.

#### FAM1 (severity 2). A missing p-value inside a family changes the others, and can be rejected

- **What happens.** `calc_power_pvals()` and `graph_optimise()` accept `NA` in a family with no message. In `FAM1.R`:
  - **Hommel**, family of two: when H2 is missing, H1's adjusted p-value doubles (0.002 instead of 0.001), as if H2 were there. When H1 is missing, H1 is given 0.001 and is rejected.
  - **Hommel**, family of three: the hypothesis with no p-value is rejected wherever it sits.
  - **Hochberg**, family of three: the same, unless the missing one is last.
  - **Holm**: a missing first member sets every adjusted p-value in the family to 1, so nothing in it is rejected.
  - **`graph_optimise()`**: with 100 missing p-values for H1 it returns a graph and a power for H1, with no message.
- **Why.** The adjustment (`src/adjust_pvals_families.cpp`) does not handle `NA`. The insertion sort (line 184) leaves `NaN` where it is, and `std::min` and `std::max` (lines 43, 53, 72 to 95) return their first argument when the other is `NaN`. So the result depends on where the missing value sits. `stats::p.adjust()`, which the code comments say the adjustment matches (lines 6 to 8), drops missing values instead.
- **Fix (suggested).** Refuse missing p-values when `families` is given, with a message naming the column. This is the same fix as B3_power, which covers missing p-values without families.

#### A4 also reaches the families path (severity 1)

- **What happens.** `A4_families.R` is the catalogue's A4 example with each hypothesis as its own family. With `sum_to_one_constraint = FALSE` and a row summing to 2, the chance of rejecting a true null is 0.0497 at 0.025, the same as without families.
- **Why and fix.** The same as A4: the row-sum check only runs when `sum_to_one_constraint = TRUE`. Patch 3 of the fix series would cover this path too.

#### MEM1 widened (severity 2). The families code uses 32-bit offsets too

- **What happens.** MEM1 says the serial kernels compute matrix offsets in 32-bit integers, which overflow above 2^31 p-values. The two new families routines do the same.
- **Why.** `src/graph_shortcut_families.cpp:199, 219, 221, 227` and `src/adjust_pvals_families.cpp:136, 175, 177, 197` declare `int N` and `int set` and index with `set + j * N`. The adjustment runs on every call with `families`, whatever `num_threads` is. So with families even multi-threaded runs reach the overflow, unlike MEM1 as catalogued.
- **Fix.** The same as MEM1: declare `N` and `set` as `R_xlen_t`. The catalogue's MEM1 script reads `src/graph_shortcut.cpp` only, so it does not show this.

#### FAM3 (severity 3). A `custom_power` entry named `family_power` is hidden

- **What happens.** With `families`, `calc_power_pvals()` adds a field `family_power`. A user measure with the same name is added as a second entry, so `out$family_power` returns the package's value and the user's is hidden (`FAM3.R`).
- **Why.** `R/calc_power.R:193` sets `power$family_power`, and line 200 appends the custom measures with `c()`. This is C20 with one more name.
- **Fix.** The reserved-name check suggested for C20, with `family_power` added to the list.

#### FAM2 (severity 4). With families, the graph's nodes are labelled H1, H2, ...

- **What happens.** With families named primary, secondary and other and `graph_constraint_free(3)`, the optimised weights, the transition matrix, `print()`, `summary()` and `plot()` label the nodes H1, H2 and H3. Node H2 is the family of hypotheses 2, 3 and 4, while `trial_success()` uses `r2` for hypothesis 2 alone. `print()` and `summary()` also list the families by name, one per node, and `family_power` uses the names (`FAM2.R`, `FA_extra.out`).
- **Why.** `graph_constraint_free()` names its nodes with `build_hyp_names()` (`R/graph_constraint.R:189`) unless it is given `names`. The family names are never passed to it. The families article says "The names become the names of the graph's nodes" (`vignettes/articles/families.qmd:112`); that holds only because the article passes the names to the constraint itself (line 201).
- **Workaround.** `graph_constraint_free(3, names = c("primary", "secondary", "other"))` gives weights and a matrix named after the families.
- **Fix (suggested).** When `families` is given and the constraint has its default names, name the nodes after the families.

## Not tested

- Group sequential designs with families or with the new kernel. Neither branch has the group sequential functions.
- Windows and macOS. Everything ran on Linux.
- The families article (`vignettes/articles/families.qmd`) was not rendered.
- Housekeeping, not an entry: `family-opt` commits its review files under `dev/review/families*`. `dev/review/families_gate.md` names a plan file on a local machine and says "All changes are uncommitted". `fast-shortcut` removed its review files before merging. `dev/` is not built into the package.

## Files

| File | Contents |
|---|---|
| `fast-shortcut/FS_kernel.R`, `.out` | Kernel checks FS1 to FS8 |
| `fast-shortcut/FS_identity.R`, `FS_identity_compare.out` | The same optimisations on `main` and `fast-shortcut`, and timings |
| `family-opt/FA_families.R`, `.out` | Families checks FA1 to FA10 |
| `family-opt/FA_extra.R`, `.out` | Sizes and labels in a families optimisation |
| `family-opt/FA_identity_compare.out` | `family-opt` without families against `main` |
| `family-opt/reprex/` | One script per finding (FAM1, FAM2, FAM3, A4_families), with its output. MEM1 widened is shown by the code lines cited |
| `catalogue_comparison.txt` | The 83 catalogue scripts on `main`, `fast-shortcut` and `family-opt` |
| `rcmdcheck.txt` | `R CMD check` and the test suite on all three |

Setup: R 4.3.3 on Linux (x86_64, g++ 13.3.0, 2 cores), each build in its own library.
