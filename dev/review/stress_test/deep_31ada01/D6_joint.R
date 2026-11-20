# fmt: skip file
# D6: the joint spending search. (a) resolved p-values at every lattice node against the fixed transform with the same
# HSD parameter; (b) the reported gain and every profile row recomputed from the stored graphs; (c) brute force: the
# graph optimised separately at every node with fixed spending; (d) reproducibility and threads; (e) a stopping rule
# and a discounted gain together. Usage: R_LIBS=<build> Rscript D6_joint.R <out.rds>
args <- commandArgs(TRUE)
suppressMessages({ library(multigrain); library(data.table) }); options(multigrain.verbosity = "silent")
hsd <- function(g) { force(g); function(a, t) gsDesign::sfHSD(a, t, g)$spend }
of  <- function(a, t) gsDesign::sfLDOF(a, t)$spend
out <- list()
## (a) resolved = fixed transform, bit for bit, at every node, for several schedules and with look-back
set.seed(61); ra <- list()
for (s in 1:4) {
    info <- switch(s, c(0.5, 1), c(0.3, 0.6, 1), rbind(c(0.4, 0.8, 1), c(NA, 0.5, 1)), rbind(c(0.25, 0.5, 0.75, 1), c(0.25, 0.5, 1, 1)))
    K <- if (is.matrix(info)) ncol(info) else length(info)
    raw <- simulate_pvalues_gsd(c(0.85, 0.75), corr_matrix = matrix(c(1, 0.5, 0.5, 1), 2), info_frac = info, nsim = 400)
    for (lb in c(FALSE, TRUE)) {
        spec <- transform_pvalues_gsd(raw, spending = list(of, sf_hsd_opt(bounds = c(-10, 2), step = 0.5)), look_back = lb)
        for (g in seq(-10, 2, by = 0.5)) {
            a <- resolve_pvalues_gsd(spec, g); b <- transform_pvalues_gsd(raw, spending = list(of, hsd(g)), look_back = lb)
            ra[[length(ra) + 1]] <- data.table(schedule = s, look_back = lb, gamma = g, max_diff = max(abs(a$pvals - b$pvals), na.rm = TRUE),
                                               na_same = identical(is.na(a$pvals), is.na(b$pvals)))
        }
    }
}
out$a <- rbindlist(ra)
cat(sprintf("(a) %d node comparisons: largest difference %g; NA pattern identical in all: %s\n", nrow(out$a), max(out$a$max_diff), all(out$a$na_same)))

## common design for (b) to (e)
set.seed(62)
raw <- simulate_pvalues_gsd(c(0.9, 0.8), corr_matrix = matrix(c(1, 0.4, 0.4, 1), 2), info_frac = c(0.5, 1), nsim = 6000)
spec <- transform_pvalues_gsd(raw, spending = list(of, sf_hsd_opt(bounds = c(-3, 1), step = 0.5)))
gain <- trial_success_gsd(0.6 * d(t1) + 0.4 * d(t2), d = c(1, 0.8))
set.seed(7); res <- graph_optimise_gsd(spec, graph_constraint_free(2), gain, num_threads = 1)
## (b) recompute the reported gain and each profile row
g_star <- res$spending_param[[1]]
pv_star <- resolve_pvalues_gsd(spec, setNames(g_star, names(res$spending_param)[1]))
rep_gain <- calc_power_pvals_gsd(pv_star, res$hyp_weight, res$trans_matrix, custom_power = list(g = gain))$g
prof <- res$spending_profile; graphs <- attr(prof, "graphs")
rb <- rbindlist(lapply(seq_len(nrow(prof)), function(i) {
    pvi <- resolve_pvalues_gsd(spec, setNames(prof$value[i], names(res$spending_param)[1]))
    gi <- calc_power_pvals_gsd(pvi, graphs[[i]]$hyp_weight, graphs[[i]]$trans_matrix, custom_power = list(g = gain))$g
    gf <- calc_power_pvals_gsd(pvi, res$hyp_weight, res$trans_matrix, custom_power = list(g = gain))$g
    data.table(value = prof$value[i], gain = prof$gain[i], gain_recomputed = gi, gain_fixed_graph = prof$gain_fixed_graph[i], fixed_recomputed = gf)
}))
out$b <- list(reported = res$power$trial_success, recomputed = rep_gain, rows = rb)
cat(sprintf("(b) reported gain %.10f, recomputed %.10f; profile rows: largest |gain - recomputed| %.2g, |gain_fixed_graph - recomputed| %.2g\n",
            res$power$trial_success, rep_gain, max(abs(rb$gain - rb$gain_recomputed)), max(abs(rb$gain_fixed_graph - rb$fixed_recomputed))))
## (c) brute force over the 9 nodes: the graph optimised afresh at each node with fixed spending
rc <- rbindlist(lapply(seq(-3, 1, by = 0.5), function(g) {
    pvg <- transform_pvalues_gsd(raw, spending = list(of, hsd(g)))
    set.seed(7); o <- graph_optimise_gsd(pvg, graph_constraint_free(2), gain, num_threads = 1)
    data.table(gamma = g, best_gain = o$power$trial_success, profile_gain = prof$gain[match(g, prof$value)])
}))
out$c <- list(joint_gamma = g_star, joint_gain = res$power$trial_success, brute = rc)
cat(sprintf("(c) joint: gamma %g, gain %.5f | brute force: best gamma %g, gain %.5f; joint minus brute-force best %.2g\n",
            g_star, res$power$trial_success, rc$gamma[which.max(rc$best_gain)], max(rc$best_gain), res$power$trial_success - max(rc$best_gain)))
rc[, profile_minus_fresh := profile_gain - best_gain]; print(rc)
## (d) reproducibility and threads
set.seed(7); res2 <- graph_optimise_gsd(spec, graph_constraint_free(2), gain, num_threads = 1)
set.seed(7); res3 <- graph_optimise_gsd(spec, graph_constraint_free(2), gain, num_threads = 2)
same <- function(x, y) identical(x$hyp_weight, y$hyp_weight) && identical(x$trans_matrix, y$trans_matrix) &&
    identical(x$spending_param, y$spending_param) && identical(x$power$trial_success, y$power$trial_success)
set.seed(99); u0 <- runif(1); set.seed(99); spec2 <- transform_pvalues_gsd(raw, spending = list(of, sf_hsd_opt(bounds = c(-3, 1), step = 0.5))); u1 <- runif(1)
out$d <- list(same_seed = same(res, res2), threads = same(res, res3), spec_draws_no_rng = identical(u0, u1))
cat(sprintf("(d) same seed, same result: %s; 1 and 2 threads, same result: %s; building a spec draws no random numbers: %s\n",
            out$d$same_seed, out$d$threads, out$d$spec_draws_no_rng))
## (e) a stopping rule with the joint search, and the reported gain recomputed with the rule
rule <- stopping_rule_gsd(r1)
set.seed(7); rese <- graph_optimise_gsd(spec, graph_constraint_free(2), gain, stopping_rule = rule, num_threads = 1)
pve <- resolve_pvalues_gsd(spec, setNames(rese$spending_param[[1]], names(rese$spending_param)[1]))
rece <- calc_power_pvals_gsd(pve, rese$hyp_weight, rese$trans_matrix, custom_power = list(g = gain), stopping_rule = rule)$g
out$e <- list(gamma = rese$spending_param[[1]], reported = rese$power$trial_success, recomputed = rece)
cat(sprintf("(e) with the rule r1: gamma %g, reported gain %.10f, recomputed with the rule %.10f\n", out$e$gamma, rese$power$trial_success, rece))
saveRDS(out, args[1])
