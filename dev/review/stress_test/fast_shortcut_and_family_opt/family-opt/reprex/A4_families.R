# A4 on the families path: sum_to_one_constraint = FALSE lets a family pass its weight on twice
# Run: Rscript A4_families.R   (needs the family-opt build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))

set.seed(1)
pvals <- simulate_pvalues(c(0.9999, 0.025, 0.025), nsim = 2e5)   # H2 and H3 are true nulls
fs <- family_spec(list(1, 2, 3))                                  # each hypothesis its own family
G <- rbind(c(0, 1, 1), c(0, 0, 0), c(0, 0, 0))                    # row 1 sums to 2
out <- calc_power_pvals(pvals, c(1, 0, 0), G, families = fs, sum_to_one_constraint = FALSE,
                        custom_power = list(any_null = trial_success(0 * r1 + (r2 || r3), verbose = "silent")))
cat("P(reject a true null) at one-sided alpha 0.025:", round(out$any_null, 4), "\n")
cat("EXPECTED: an error: row 1 sums to 2\n")
