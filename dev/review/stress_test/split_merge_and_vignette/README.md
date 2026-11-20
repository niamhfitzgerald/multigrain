# Stress test of `split-merge` and `trial_success_vignette`

Niamh Fitzgerald, 18 November 2026. Two branches of GSK-Biostatistics/multigrain that start from `main` and are in neither `main` nor `gsd-build-spending`.

| Branch | Commit | Pull request | What it adds |
|---|---|---|---|
| `split-merge` | `ff9d907` (22 October) | #53, open | A new mutation for the genetic algorithm of `graph_optimise()`: each call merges two entries of one weight vector or transition row, or moves weight between two of them by a reflected Cauchy step. The defaults become `pcrossover = 0` and `pmutation = 1` |
| `trial_success_vignette` | `b1c9f21` (4 November) | #54, open | A rewrite of the trial success article for `main`, its data script and two stored graphs |
| `main` (baseline) | `508d0b7` | | Development version 1.0.0.9002 |

Neither branch has the group sequential functions, so most of this covers the fixed-sample code. One check builds `split-merge` merged into `gsd-build-spending`.

Update, 20 November: on 18 November `split-merge` moved to `c441d95` (PR #56: documentation, a check that `scale` is finite, and test changes; 4 files). A dry-run merge of `c441d95` into `gsd-build-spending` (`git merge-tree`) gives the same two conflicts, in `.gitignore` and `NEWS.md`, and the merged tree still calls `.make_cauchy_mutation_multi()` (`R/optimisation_gsd.R:572`, `R/optimisation_gsd_opt.R:380`) without defining it. So SM1 still holds [read]. The other checks below were run on `ff9d907` and not rerun on `c441d95`.

## In one minute

- **`split-merge` would break the group sequential optimiser if merged into `gsd-build-spending`.** Merged into `31ada01`, `graph_optimise_gsd()` stops with "could not find function \".make_cauchy_mutation_multi\"" whenever the global search runs, which is its default, and so does the joint spending search. Git reports conflicts only in `.gitignore` and `NEWS.md`, so the merge itself would not show it. Alex's report of 5 November (`dev/review/hsd_opt/search_quality_report.md` on `gsd-build-spending`) predicted this by reading the merged tree; here it was run.
- **The new mutation is sound.** In 19,998 calls over six graph constraints, every child decodes to a valid graph, keeps every fixed entry, differs from its parent and leaves everything outside its group alone.
- **It finds slightly better graphs, more slowly.** On three problems with 4 and 6 hypotheses, the graphs scored 0.0006 to 0.0018 higher on fresh trials than with the old mutation, and varied less between seeds. They took about 1.5 to 3.2 times as long.
- **The catalogue is unchanged on `split-merge`.** B2 still holds: whenever the global solution is returned, a fixed edge of 1e-4 comes back as 0.001. Its script's seed now happens to return the local solution, so the script needs another seed once the branch is merged.
- **The trial success article runs, but it uses the old option name.** It sets `options(multigrain_verbosity = "silent")`. Knitted against `main`, where that name is ignored (ENV08), it prints the compile message 14 times; on its own branch it prints none. Otherwise the two knitted articles are identical.
- **The rewritten article fixes DOC6** (no roxygen-style link is left) but commits its Quarto intermediate again (UT5). It merges into `main` cleanly. Merging it into `gsd-build-spending` conflicts in `vignettes/articles/get-started.Rmd`, `trial_success.qmd` and `trial_success.rmarkdown`.

## `split-merge`

### Findings

#### SM1. Merged into `gsd-build-spending`, the group sequential optimiser stops at its global search

- **What happens.** `split-merge` replaces `.make_cauchy_mutation_multi()` (it moves to `dev/archived_code/cauchy_mutation.R`, which the package build ignores). `graph_optimise()` gets the new mutation, but `gsd-build-spending` still calls the old one in `graph_optimise_gsd()` (`R/optimisation_gsd.R:572`) and in the joint spending search (`R/optimisation_gsd_opt.R:380`). After a merge both stop at the first global search: `SM_merge_break.out` shows "could not find function \".make_cauchy_mutation_multi\"" for fixed spending and for the joint search. With `global_search = FALSE` the optimiser runs. The merged build also changes the defaults `pcrossover` from 0.2 to 0 and `pmutation` from 0.8 to 1; Alex's report traces them to the group sequential paths through `control_prepare_dims()`.
- **How it was found.** The build is the tree of `git merge-tree --write-tree origin/gsd-build-spending origin/split-merge`, whose only conflicts (in `.gitignore` and `NEWS.md`) the package build does not read.
- **Potential fix (suggested).** When the branches meet, either give the group sequential optimisers the split-merge mutation (its groups would need the spending genes, which `.sm_groups()` does not know about), or keep `.make_cauchy_mutation_multi()` in `R/` for them. Alex's report notes that the split-merge move never changes a spending gene; on three small designs it tried the move with and without a 20% redraw of each spending gene and saw no loss, while noting that this does not clear it for larger designs.

#### B2 on `split-merge`

The catalogue's B2 script returns the local solution on this branch, so its output differs from `main`. `SM_B2_seeds.R` reruns it with seeds 1 to 20: the global solution was returned 14 times on `split-merge` (16 on `main`), and every time the fixed edge of 1e-4 came back as 0.001. The cause is in `param_to_solution()`, which the branch does not change.

### Checks

| Script | What it checks | Result |
|---|---|---|
| `SM_mutation.R` | 19,998 calls of the mutation (3,333 per constraint) over six constraints (free with 3 and 6 hypotheses, weights fixed, one weight fixed, a row fully fixed and a row with one free entry, fixed edges of 0.001 and 1e-4), from 50 random valid parents per constraint | Every child in [0, 1], decodes to a valid graph, keeps every fixed entry, differs from its parent, and leaves positions outside the mutated group alone. The parents' free entries are shrunk by a relative 1e-12, so that rounding cannot leave a derived entry below 0. Without that, one parent decoded to an entry of -2.2e-16 and its children inherited it; the mutation did not cause it, but a population drawn that way would hold invalid graphs |
| `SM_quality.R`, `SM_quality_compare.R` | `graph_optimise()` on the same three problems, seeds and 10,000 trials on `main` and on `split-merge`; each graph then scored on the same 100,000 fresh trials | See below |
| `SM_merge_break.R` | The group sequential optimisers on a build of `split-merge` merged into `31ada01` | SM1 |
| `SM_B2_seeds.R` | B2 with 20 seeds, on both builds | B2 holds on both |
| `catalogue_comparison.txt` | The catalogue scripts on `split-merge` and `main` | 53 the same; the 9 that differ are run-to-run values, version and NEWS lines, B2's seed and DOC8's rebuilt graph |

The quality comparison (`SM_quality_compare.out`), as fresh gain:

| Problem | `main`: mean (range) | `split-merge`: mean (range) | Paired difference, split-merge minus main (SE) | Mean time per run, `main` / `split-merge` |
|---|---|---|---|---|
| 4 hypotheses, weighted gain, 5 seeds | 0.7647 (0.7634 to 0.7656) | 0.7654 (0.7653 to 0.7655) | +0.0008 (0.0004) | 36 s / 77 s |
| 4 hypotheses, gated gain, 5 seeds | 0.7710 (0.7697 to 0.7720) | 0.7716 (0.7708 to 0.7719) | +0.0006 (0.0004) | 37 s / 54 s |
| 6 hypotheses, weighted gain, 3 seeds | 0.7144 (0.7136 to 0.7155) | 0.7162 (0.7160 to 0.7163) | +0.0018 (0.0005) | 78 s / 249 s |

- The gains differ by a few thousandths at most, and the seeds are few, so read this as "no worse, a little better and more repeatable", not as a measured improvement.
- The in-sample optimism (reported minus fresh gain) was larger with `split-merge` for 6 hypotheses: 0.0051 against 0.0025. A search that fits the simulated trials better also fits their noise better.
- Times are rough: one thread, with other jobs sharing the 2 cores.

### Not tested

- Larger graphs, constrained graphs beyond the six of `SM_mutation.R`, and the branch's own benchmark settings.
- `split-merge` with the group sequential optimisers after a fix for SM1.

## `trial_success_vignette`

| Check | Result |
|---|---|
| `VG_knit.R`: the article knitted against the branch's own build (`b1c9f21`, version 1.0.0.9001) and against `main` (`508d0b7`) | Both knit. The two chunks marked `error: true` show their errors. 0 compile messages on the branch, 14 on `main` (`VG_knit_branch.out`, `VG_knit_main.out`). Apart from those messages the two knitted articles are identical (`VG_knit_compare.out`) |
| `catalogue_comparison.txt`: the catalogue scripts on the branch and on `main` | 53 the same. DOC6 is fixed in the rewritten article. UT5: `trial_success.rmarkdown` is committed again, current with its `.qmd` on this branch, and `*.rmarkdown` is still not ignored. The others are run-to-run values, version and NEWS lines, and DOC15's link to the article |
| Dry-run merges (`git merge-tree`) | Into `main`: no conflict. Into `gsd-build-spending`: conflicts in `vignettes/articles/get-started.Rmd`, `vignettes/articles/trial_success.qmd` and `vignettes/articles/trial_success.rmarkdown`, where both branches have their own article |

Small points read in the article:

- It says a trial success function is a map to the non-negative reals. `trial_success()` accepts negative values, and entry A1 is about a gain that is negative for every graph. The article could say "should" rather than imply the package checks it.
- `VG_knit_compare.out` was made with `diff <(grep -v "compiled and sourced successfully" main.md) branch.md`.

Not tested: the data script (`data-raw/trial_success_vignette.R`, optimisations with 100,000 global trials) was not rerun, so the stored graphs were not reproduced; the article was knitted with knitr, not rendered with Quarto.

## Files

| Path | Contents |
|---|---|
| `split-merge/SM_mutation.R`, `.out` | Properties of the mutation |
| `split-merge/SM_quality.R`, `SM_quality_compare.R`, `SM_quality_compare.out`, `SM_quality_main.rds`, `SM_quality_split-merge.rds` | The quality comparison and its raw results |
| `split-merge/SM_merge_break.R`, `.out` | SM1 |
| `split-merge/SM_B2_seeds.R`, `SM_B2_seeds_main.out`, `SM_B2_seeds_split-merge.out` | B2 with 20 seeds |
| `split-merge/catalogue_comparison.txt` | The catalogue on `split-merge` against `main` |
| `trial_success_vignette/VG_knit.R`, `VG_knit_branch.out`, `VG_knit_main.out`, `VG_knit_compare.out` | The article knitted on both builds |
| `trial_success_vignette/catalogue_comparison.txt` | The catalogue on the branch against `main` |

Environment: as in the main README, with graphicalMCP 0.3.0, knitr 1.45 and data.table from the system library.
