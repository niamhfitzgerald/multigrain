# The stopping rule has to be written into the gain twice, and the levels
# expression three times. Nothing checks that the copies agree.
source("_common.R")
stop <- "((t1 == 1) && (t2 == 1))"
value_at_s1 <- "(10 * (t1 == 1) + 5 * (t2 == 1) + 5 * (t3 == 1))"
value_by_s2 <- "(10 * r1 + 5 * r2 + 5 * r3)"
S <- 2
expr <- sprintf("%s * %g * %s + (1 - %s) * (%s + %g * %s)",
                stop, S, value_at_s1, stop, value_by_s2, S - 1, value_at_s1)
g <- trial_success_gsd(!!expr, K = 2, verbose = "silent")
nchar(g$objective)   # 170 characters for three hypotheses; 600 for five
cat(g$objective, "\n")
# A typo in the second copy of the rule is not detected:
expr_typo <- sub("\\(1 - \\(\\(t1 == 1\\) && \\(t2 == 1\\)\\)\\)", "(1 - ((t1 == 1) && (t3 == 1)))", expr)
g_typo <- trial_success_gsd(!!expr_typo, K = 2, verbose = "silent")
calc_power_pvals_gsd(pv, w, G, custom_power = list(ok = g, typo = g_typo))[c("ok", "typo")]
