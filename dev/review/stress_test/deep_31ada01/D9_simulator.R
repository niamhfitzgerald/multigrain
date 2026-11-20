# fmt: skip file
# D9: does simulate_pvalues_gsd() give the documented joint distribution? Empirical correlations of the z-statistics
# against rho_ij * sqrt(min(t)/max(t)), and the final-analysis rejection rate at alpha against power_nominal, for
# several schedules, including a hypothesis complete at the interim and one without interim data.
# Usage: R_LIBS=<build> Rscript D9_simulator.R
suppressMessages({ library(multigrain); library(data.table) })
cases <- list(
    common      = list(info = c(0.4, 0.7, 1), rho = 0.5),
    h1_complete = list(info = rbind(c(1, 1), c(0.5, 1)), rho = 0.6),
    h2_complete = list(info = rbind(c(0.5, 1), c(1, 1)), rho = 0.6),
    h2_late     = list(info = rbind(c(0.3, 0.6, 1), c(NA, 0.5, 1)), rho = 0.4),
    staggered   = list(info = rbind(c(0.25, 0.5, 1, 1), c(0.2, 0.6, 0.8, 1)), rho = 0.7)
)
pw <- c(0.85, 0.7); n <- 2e5; out <- list()
for (nm in names(cases)) {
    cs <- cases[[nm]]; info <- if (is.matrix(cs$info)) cs$info else matrix(cs$info, 2, length(cs$info), byrow = TRUE)
    K <- ncol(info); R <- matrix(c(1, cs$rho, cs$rho, 1), 2)
    set.seed(9); P <- simulate_pvalues_gsd(pw, corr_matrix = R, info_frac = cs$info, nsim = n)
    Z <- qnorm(P, lower.tail = FALSE)
    cols <- which(!is.na(Z[1, , ]), arr.ind = TRUE)                        # (hypothesis, analysis) pairs with data
    cols <- cols[!duplicated(info[cols]  * 0 + seq_len(nrow(cols))), , drop = FALSE]
    rows <- list()
    for (a in seq_len(nrow(cols))) for (b in seq_len(nrow(cols))) if (a < b) {
        i <- cols[a, 1]; k <- cols[a, 2]; j <- cols[b, 1]; l <- cols[b, 2]
        ti <- info[i, k]; tj <- info[j, l]
        if (i == j && ti == tj) next                                        # the same statistic copied forward
        th <- (if (i == j) 1 else R[i, j]) * sqrt(min(ti, tj) / max(ti, tj))
        em <- cor(Z[, i, k], Z[, j, l])
        rows[[length(rows) + 1]] <- data.table(case = nm, pair = sprintf("Z%d,%d vs Z%d,%d", i, k, j, l), t = sprintf("%g vs %g", ti, tj),
                                               documented = round(th, 4), empirical = round(em, 4), diff = round(em - th, 4))
    }
    cr <- rbindlist(rows)
    fin <- sapply(1:2, function(i) mean(P[, i, K] < 0.025))
    out[[nm]] <- list(cor = cr, final_power = fin)
    cat(sprintf("%-12s largest |empirical - documented| correlation %.4f (SE about %.4f); final-analysis power %.4f %.4f (nominal %.2f %.2f)\n",
                nm, max(abs(cr$diff)), 1 / sqrt(n), fin[1], fin[2], pw[1], pw[2]))
}
saveRDS(out, "D9_simulator.rds")
worst <- rbindlist(lapply(out, `[[`, "cor"))[order(-abs(diff))][1:6]
print(worst, row.names = FALSE)
