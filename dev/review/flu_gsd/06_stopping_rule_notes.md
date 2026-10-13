# User-testing notes: specifying a stopping rule in multigrain's GSD extension

Niamh Fitzgerald, 13 October 2026. Written while running the flu vaccine
scenarios (tasks 2 and 3 of the 13 October brief) on `gsd-build` at commit
ee91a11.

## Scope

The brief describes the stopping rule as a list giving the rule at each
analysis. No branch I can see (`gsd-build`, `main` at 1.0.0, or any other
pushed branch) has that argument, so I could not test it directly. What I
tested is the only way to express a stopping rule today: writing it into the
`trial_success_gsd()` expression. Sections 1 to 3 are findings from that.
Section 4 is a checklist for the list interface once it exists, with the
cases I would run first. Every finding below has a reprex in `reprex/`.

## 1. What works

- A rule on season-1 decision times compiles and runs: `((t1 == 1) && (t2 == 1)
  && (t3 == 1))`. The R-side value computed from the decision-time matrix and
  the compiled gain agree exactly (to 1e-15) on every graph, rule and S tried.
- `m` and `K` mismatches between the gain and the p-values are caught with a
  clear message when the gain is used (`custom_power$p and pvals disagree on
  the number of hypotheses`).
- Unsupported operators (`&`, `!`, `ifelse`, `max`) fail at compile time with a
  message that lists what is allowed.

## 2. Confusing or error-prone

1. **The rule has to appear twice in the expression.** The gain is
   `stop * S * L(at season 1) + (1 - stop) * L(timed)`, so `stop` is written
   out twice and the levels expression three times. The printed `objective`
   for the alternative rule is 600 characters long and unreadable. Nothing
   checks that the two copies agree. (reprex `R1_duplicated_rule.R`)

2. **Every reported power ignores the rule.** `calc_power_pvals_gsd()` returns
   `local_power`, `local_power_by_analysis`, `mean_decision_look` and
   `time_distribution` for the always-continue trial. In the three-hypothesis
   reprex the power of H3 is 0.459 in the output but 0.370 under a rule that
   stops 36% of trials. A reader of the result object has no way to know a
   rule was applied. (reprex `R2_power_ignores_rule.R`)

3. **The stopping probability needs a dummy gain.** To get P(stop) you write
   the rule as its own gain and pad it so `m` is right:
   `trial_success_gsd(!!"((t1 == 1) && (t2 == 1) && (t3 == 1)) + 0 * t5", K = 2)`.
   Without the `0 * t5` the gain has `m = 3` and is rejected at use with a
   message about hypotheses, which does not say why. (reprex `R3_p_stop_padding.R`)

4. **Writing the rule on `r` instead of `t` compiles and means something
   else.** `(r1 && r2)` is "both rejected by the end", not "both rejected at
   season 1". There is no warning. For a two-analysis design the only decision
   time at which a stop can be declared is 1, so a rule that uses `r` is
   almost certainly a mistake. (reprex `R4_rule_on_r.R`)

5. **Impossible looks compile silently.** `(t1 == 3)` with `K = 2` compiles to
   a gain that is identically zero. So does a rule that can never be met on the
   graph (a trigger hypothesis with no alpha at season 1). The optimiser then
   maximises a constant and returns a graph without complaint. An error for
   `t == k` with `k > K`, and a warning when the gain is constant over the
   training trials, would catch both. (reprex `R5_impossible_look.R`)

6. **An early-claim bonus triggers a warning.** The natural encoding of "a claim
   at the interim is worth S times a claim at the end" is a discount table
   `d = c(S, 1)`. Any S above 1 warns that multipliers must lie in [0, 1]. The
   workaround is `d = c(1, 1 / S)`, which rescales the whole gain and is easy
   to forget when comparing scenarios. (reprex `R6_bonus_warning.R`)

7. **No `max()`, no `!`.** Highest-level values need
   `(r1 || r2 || r4)` style sums, and "did not stop" has to be written
   `(1 - stop)`. Both are fine once you know, but the error message for `!`
   lists the allowed operators without saying how to negate. (reprex
   `R7_negation.R`)

8. **Precedence.** `t1 == 1 && t2 == 1 * 5` compiles and gives 0 everywhere.
   The help page does warn, but the warning is in the Details section rather
   than near the examples.

9. **Per-trial values are not available.** Monte Carlo standard errors for a
   paired comparison need the per-trial gain, which means calling
   `multigrain:::graph_shortcut_gsd()` and `multigrain:::.gsd_kernel_matrix()`
   and re-implementing the gain in R. A `per_trial = TRUE` option on
   `calc_power_pvals_gsd()` or an exported decision-time function would avoid
   that.

## 3. Documentation gaps

- `trial_success_gsd()` does not say that a stopping rule can be written into
  the gain, nor that doing so leaves the power output unchanged.
- The relationship between a rule written in the gain and
  `graphicalMCP`'s way of passing only the analyses that took place is not
  described anywhere.
- Nothing says what a stopped trial's decision times look like (`t = 0` for
  hypotheses not rejected before the stop). This matters once a rule exists
  as an argument, since the gain's `ri` then changes meaning.

## 4. Checklist for the list-per-analysis interface

Test first, in this order:

1. Shape: a list of length K with `NULL` (or `FALSE`) at the final analysis.
   Does it reject a list of length K - 1, length K + 1, or one with a rule at
   analysis K?
2. No stopping: `list(NULL, NULL)` must reproduce the always-continue results
   exactly.
3. One hypothesis: `list(r1, NULL)` (stop once the primary is rejected) must
   give P(stop) equal to the season-1 power of H1 with all alpha on H1.
4. Rule that can never be met: a trigger hypothesis with zero weight at the
   interim. Expect a warning, not a silent P(stop) = 0.
5. Rule on a hypothesis that has no data at the interim (`NA` information
   fraction). Expect an error.
6. Rules written on `r` versus `t`: define which symbols are allowed inside a
   rule. If only `r` is allowed (as at the current analysis), say so, because
   that is the opposite of the gain's convention.
7. Three analyses with rules at 1 and 2: a trial that fails the rule at 1 and
   meets it at 2 must stop at 2 and keep its analysis-2 rejections.
8. Reported power: `local_power`, `local_power_by_analysis`, and
   `time_distribution` should reflect the rule, and the stopping look should
   be reported (distribution and mean).
9. The gain's `ri` after a stop: rejections that would have happened later
   must not count. Check against an R reference (the `trial_values()` function
   in `00_setup.R` is one).
10. Interaction with `look_back = TRUE`.
11. Error messages: name the argument, the analysis and the hypothesis.
