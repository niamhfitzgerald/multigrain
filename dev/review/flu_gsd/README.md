# Flu vaccine trial: group sequential design optimisation with multigrain

Scripts for optimising the multiplicity graph and the alpha-spending parameter
of a two-season vaccine trial (interim at the end of season 1, final at the
end of season 2, five hypotheses) with multigrain's group sequential
extension. Runs on the `gsd-build` branch as it is.

The trial inputs are confidential. They live in `config_local.R`, which is
git-ignored, as are `runs/` (optimiser output) and `results/`. Copy
`config_template.R` to `config_local.R` and fill it in before running anything.

## Value model

Highest-level claim values: each endpoint is worth the highest level it
reaches (ILI 10, 15 or 20; SID 10 or 15; 35 in all). A level reached at the
interim is worth S times its value, whether or not the trial stops. A trial
that stops at the interim keeps only the levels it had reached there. In
multigrain's gain grammar this is

    stop * S * L(at season 1) + (1 - stop) * (L(by season 2) + (S - 1) * L(at season 1))

where `L(.)` is the levels expression and `stop` is the stopping rule on the
season-1 decision times. See `gain_expr()` in `00_setup.R`.

## Scripts, in order (run from this folder)

| Script | What it does |
|---|---|
| `00_setup.R` | Inputs, simulator (binomial counts, Wald Z on log RR), spending sets, gains, stopping rules, scoring with paired Monte Carlo SEs, resumable optimiser wrapper. Sourced by the others. |
| `run_scenarios.R` | Optimises and evaluates a table of scenarios (rule, spending, S). Sourced by 01 and 02. |
| `01_continue_regardless.R` | Task 1: no stopping, S = 1, 1.5, 2. |
| `02_stopping_rules.R` | Tasks 2 to 4: protocol rule and alternative rule, OBF or Pocock on SUP_SID0, S = 1, 1.5, 2. |
| `03_gamma.R` | Task 5: one Hwang-Shih-DeCani gamma shared by all hypotheses, optimised in an outer loop over the graph optimiser; `Rscript 03_gamma.R protocol 2`. |
| `04_summary.R` | Summary table (`results/summary_table.md`) and the figures. |
| `05_participants.R` | Extra participants per arm the protocol design would need to match each optimised design. |
| `06_stopping_rule_notes.md` | User-testing notes on specifying a stopping rule, with reprexes in `reprex/` (no trial inputs). |
| `write_up.md` | Short write-up of the results. |

Optimiser runs are saved one file per seed in `runs/` and skipped when the
file exists, so every script can be stopped and restarted. Threads:
`FLU_THREADS=4 Rscript 02_stopping_rules.R`.

Seeds: training trials 20251208, test trials 1, optimiser seeds 11 and 22.
Every reported gain is on 100,000 fresh test trials with the Monte Carlo SE,
and every difference is paired on the same trials.
