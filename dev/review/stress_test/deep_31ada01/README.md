# Deep stress test of `gsd-build-spending` at `31ada01`

Niamh Fitzgerald, 20 November 2026. multigrain built from `gsd-build-spending` at `31ada01` (5 November 2026), R 4.3.3 on Linux (x86_64, 2 cores), gsDesign 3.11.0, mvtnorm 1.2.4, GA 3.2.5, nloptr 2.0.3, data.table 1.14.10, callr 3.7.5 and knitr 1.45.

The reruns in the rest of this folder check that each known error is still there. This test asks two other questions. Are the group sequential results right? Does every function cope with awkward input? Most checks compare multigrain with a reference written without it. [`ref_lib.R`](ref_lib.R) implements the group sequential graphical procedure from the papers (Bretz et al. 2009; Maurer and Bretz 2013) and the help pages. Its boundaries come straight from `gsDesign::gsBound1()` at the level a hypothesis holds, with no repeated p-values and no interpolation. Its p-values are simulated with mvtnorm.

Labels: [simulated] is a computational check, [read] is something read in the code. Nothing here is proved.

## Results

| Check | What it compares | Result |
|---|---|---|
| D1. Input sweep | 244 awkward inputs to the simulators, the transform, the power function, the optimiser, the gains, the stopping rules, the spending specs, `resolve_pvalues_gsd()`, the small helpers and the print methods. A driver restarts R after a crash, so a crash would be recorded. | 72 accepted, 155 refused with a message from multigrain or rlang, 16 stopped with an error from base R, gsDesign, mvtnorm or the user's own function. 1 was stopped by the driver's 900 s limit (`grid_size = 1e6`, after about 15 minutes; the tsv records it as a crash with exit code 124, the code of `timeout`). No R session ended on its own. Each outcome was reviewed: two new entries (DS1, DS2); the rest are correct, already in the catalogue, or small items below. [simulated] |
| D2. Decision times against the reference | 250 random designs: 2 to 4 hypotheses, 2 to 4 analyses, 8 spending functions, look-back, late starts, hypotheses complete before the last analysis, graphs that do not sum to 1, 5 stopping rules. 2,000 trials each. | The decision times are the same in all 500,000 trials. Each trial is passed to the gain once, and `local_power` agrees with the recorded times. [simulated] |
| D3. Repeated p-values against exact ones | 120 designs: 7 spending functions, alpha from 1e-4 to 0.2, 2 to 5 analyses, `grid_size` 64, 256 and 1024. 4,967 repeated p-values, each against the level at which the gsBound1 boundary equals the raw p-value (root finding). | At the default `grid_size` of 1024 the largest relative error is 7.7e-6. One design was refused (C1). Coarser grids: see "Evidence for C4" below. [simulated] |
| D4. Familywise error | 160 random designs, 40,000 trials each, global and partial nulls. 9 spending functions, including HSD with parameter -10 and 2 (wider than the default lattice of `sf_hsd_opt()`, -4 to 1), look-back, 4 stopping rules or none, alpha 0.01 to 0.2. | 157 designs ran; 3 were refused (C1). The largest excess over alpha, in standard errors, is z = 2.59 (0.0270 at alpha 0.025); the output line labelled "largest familywise error relative to alpha" reports this design. None is above alpha plus 3 standard errors. Over 157 designs that largest z is what chance gives. [simulated] |
| D5. Gains and stopping rules | 150 random gains inside the documented grammar, compiled by `trial_success_gsd()`, against plain R evaluation on the same decision times. 60 random stopping rules against the reference. | Gains: 147 of 150 agree to 1e-12; the other 3 are NaN in both, from a division by 0 when a hypothesis is never rejected (DS3). Rules: 59 agree in every trial. `r1 + r2` is refused when used, with a clear message (already a small item in the main README). A first run (`D5_gain_rule.R`) drew 110 gains partly outside the grammar: 25 compiled and agreed with R, 48 were refused as the help says (`!`, `&&` or `||` between numbers, a constant, and one `!!`, which is rlang's injection), and 37 stopped with C21's error, since they leave out H3. [simulated] |
| D6. Joint spending search | (a) Resolved p-values at every lattice node against the fixed transform with the same parameter. (b) The reported gain and every profile row, recomputed. (c) Brute force: the graph optimised afresh at each of 9 nodes. (d) Seeds and threads. (e) A stopping rule with the joint search. | (a) The same, bit for bit, in 200 comparisons (4 schedules, with and without look-back). (b) Equal to about 1e-15. (c) The joint search picks the same value and gain as brute force; its profile is within 5.3e-5 of a fresh optimisation at every node. (d) The same seed gives the same result on 1 and 2 threads, and building a spec draws no random numbers. (e) The reported gain recomputes exactly with the rule. [simulated] |
| D7. Extreme designs | 21 designs, each in its own R process with a 20-minute limit: 6 and 10 analyses, an interim at 1% and 0.1%, alpha from 1e-6 to 0.5, 8 to 17 hypotheses, every hypothesis starting late, different schedules, `grid_size` 64 and 4096, 1,000,000 trials, and the joint search on a lattice of 97 nodes. | 19 ran. Every familywise error is at or below alpha, or above it by less than one standard error. The longest run was the 97-node lattice (188 s). Two were refused, as documented: an interim at 1% with O'Brien-Fleming spending (C1), and a stopping rule with 17 hypotheses (the limit is 16). [simulated] |
| D8. Articles | The four articles knitted with knitr against the build. | All four knit. The only errors shown are the four in chunks marked `error: TRUE` in `graph_constraint.qmd`. `gsd-joint-spending.Rmd` reads stored results (its analysis chunks are `eval=FALSE`), so its analysis code was not run here. [simulated] |
| D9. Simulator | `simulate_pvalues_gsd()` against its documented joint distribution: 5 schedules, including a hypothesis complete at the interim and one with no interim data, 200,000 trials each. | All 62 correlations are within 0.0037 of rho times sqrt(min t / max t), with a standard error of about 0.002. Power at the final analysis is within 0.0013 of the nominal power. [simulated] |
| D10. Output identities | 60 random designs, half with a stopping rule. 11 identities that follow from the help page, such as local power equal to 1 minus the share never rejected, power by analysis equal to the cumulative decision times, and the stopping distribution summing to 1. | 660 checks, none failed. [simulated] |

## New entries

- [DS1](../2_misleading_or_broken_contract.md#DS1) (severity 2): an `info_frac` given to `transform_pvalues_gsd()` replaces the one the simulator attached, with no message, and the type I error is not kept. Found in D1.
- [DS2](../3_validation_and_messages.md#DS2) (severity 3): `alpha = 0` and `alpha = 1` are accepted as levels, and the group sequential transform then fails inside gsDesign or base R, or runs at a level of 1. Found in D1.
- [DS3](../3_validation_and_messages.md#DS3) (severity 3): a gain that is 0/0 in some trials compiles without a word; its power is NaN and the optimisers stop inside GA or nloptr. Found in D5.

Their scripts are in [`../reprex/`](../reprex/). The fixes of DS1 and DS3 were tried in a session. The code of each fix (`DS1_fix.R`, `DS3_fix.R`), the scripts that put it in place, and their output are in [`fix_tests/`](fix_tests/).

Two candidates turned out to be in the catalogue already. A `custom_power` entry of the wrong type is always called "a string": that is the second defect of C20. A gain that leaves out the last hypothesis is refused: that is C21. C20's fix of the message was tried again in a session on `31ada01`, on both power functions, and still gives "not a number", "not NULL" and "not `TRUE`" (`fix_tests/C20_fix_recheck.R`) [simulated].

## Small items without an entry

Seen on `31ada01` [simulated]. Each is a row of `D1_sweep.tsv` unless `small_items.out` is named.

- `grid_size` has no upper limit. `grid_size = 1e6` ran for about 15 minutes, until the driver's 900 s limit stopped it. At 4096 a design took 11 s in D7 (simulation, transform and power together).
- `simulate_pvalues_gsd(numeric(0), ...)` stops with "non-numeric argument to mathematical function" from `sqrt()`, and `info_frac = c(0.5, Inf)` stops with "infinite or missing values in 'x'" from `eigen()`. B3_simulators and B4 cover the neighbouring cases; their fixes may or may not catch these two.
- `resolve_pvalues_gsd(spec)` with no value stops with R's "argument "spending_param" is missing, with no default".
- A `custom_power` function that returns two values, or a string, stops with the message of `vapply()` ("values must be length 1, but FUN(X[[1]]) result is length 2"), which does not name `custom_power` or the entry.
- `normalise_sum(c(0, 0))` returns `c(0, 0)` without a message. Weights that sum to 0 cannot be normalised.
- At `alpha = 1e-12` and `1e-15` the transform refuses `sfLDOF` with "does not spend the whole level by full information ... A spending function that stops short would silently waste alpha". At those levels the function spends slightly more than the level (1.00009e-12 and 1.11e-15), not less, so the message describes the wrong direction. At 1e-13 it spends less and the message is right; at 1e-11 the transform gives C1's message (`small_items.out`; the 1e-15 case is also in D1). No real design uses such a level.
- Two analyses at the same information fraction, such as `info_frac = c(0.5, 0.5, 1)`, are accepted by `simulate_pvalues_gsd()`. The transform then stops with C1's message ("The boundary table cannot be inverted ... Try a larger `grid_size` or a later information fraction"), which does not mention the repeated fraction (`small_items.out`).

## Evidence for C4 (the minimum `grid_size`)

C4 suggests raising the minimum `grid_size` from 2 to 64. D3 measured the error of the repeated p-values on 119 designs and 4,967 p-values (the last table of `D3_transform.out`) [simulated]:

| Raw p-values | `grid_size` 64 | 256 | 1024 (default) |
|---|---|---|---|
| at least 1e-12: largest relative error | 0.3% | 0.01% | 0.0008% |
| at least 1e-12: largest error towards a smaller p-value | 0.18% | 0.009% | 0.0008% |
| below 1e-12, at the first analysis: largest relative error | 66% | 3.8% | 7e-15 |

At later analyses, raw p-values below 1e-12 were off by at most 0.06% at 64. An error towards a smaller p-value is the direction that could raise the type I error. At 64 it is small for ordinary p-values. Below about 1e-12 at the first analysis it grows quickly on a coarse grid, which is C5's region. In D7 a design with three analyses gave a familywise error of 0.0249 at both 64 and 4096. So 64 removes C4's problem. 256 would also keep the first-analysis error small, in about a quarter of the default's time (a design's run time grows about in line with `grid_size`: in D7, 0.2 s at 64 and 11 s at 4096, for simulation, transform and power together).

## Not tested

- Windows and macOS.
- The analysis code of `gsd-joint-spending.Rmd` (its analysis chunks are not run when it is knitted) and its data script (HS10).
- The familywise error of the joint search over many designs. D4 used fixed spending functions, including the lattice's ends; D6 checked one design in depth.
- More than 5 hypotheses in D2 and D4. D7 ran 8, 12 and 16 hypotheses for the familywise error only.
- DS2's fix, and the full test suite with the fixes of DS1 and DS3.
- The fix series of 73 patches against these checks (it is not in this repository).

## Files and how to rerun

Run each script from this folder, with the build on the library path, for example `R_LIBS=<library with multigrain at 31ada01> Rscript D4_fwer.R 160 40000 404 D4_fwer.rds`. `ref_lib.R` is sourced by D2 to D5 and D10.

| Script | Arguments used | Output |
|---|---|---|
| `D1_driver.sh` (with `D1_setup.R`, `D1_cases.R`, `D1_runner.R`) | none; set `R_LIBS` first | `D1_sweep.tsv`: case, outcome, error class, result or message, warnings, seconds |
| `D2_reference.R` | `250 2000 2026 D2_reference.rds` | `D2_reference.out` |
| `D3_transform.R` | `120 303 D3_transform.rds` | `D3_transform.out` |
| `D4_fwer.R` | `160 40000 404 D4_fwer.rds` | `D4_fwer.out` |
| `D5_gain_rule.R` | `110 60 505 D5_gain_rule.rds` | `D5_gain_rule.out` (the rules, and the first run of the gains; see D5) |
| `D5b_gains.R` | `150 515 D5b_gains.rds` | `D5b_gains.out` |
| `D6_joint.R` | `D6_joint.rds` | `D6_joint.out` |
| `D7_extremes.R` | `D7_extremes.rds` | `D7_extremes.out` |
| `D8_articles.R` | an output folder; run from the repository root | `D8_articles.out` |
| `D9_simulator.R` | none | `D9_simulator.out` |
| `D10_outputs.R` | none | `D10_outputs.out` |
| `small_items.R` | none | `small_items.out` |
| `fix_tests/` | see each script's header | the code of the DS1 and DS3 fixes, the scripts that put them in place in a session, C20's recheck, and their output |

The `.rds` files are not kept here; the `.out` files hold the results quoted above.
