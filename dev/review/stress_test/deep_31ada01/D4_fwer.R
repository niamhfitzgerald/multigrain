# fmt: skip file
# D4: familywise error of the package's procedure on random designs, with p-values simulated by mvtnorm (sim_raw in
# ref_lib.R), under the global null and under partial nulls. Spending includes the lattice extremes of the joint search.
# Usage: R_LIBS=<build> Rscript D4_fwer.R <n_designs> <nsim> <seed> <out.rds>
args <- commandArgs(TRUE); nsim <- as.integer(args[2])
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "ref_lib.R"))
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
hsd <- function(g) { force(g); function(a, t) gsDesign::sfHSD(a, t, g)$spend }
sf_menu <- list(sfLDOF = function(a, t) gsDesign::sfLDOF(a, t)$spend, sfLDPocock = function(a, t) gsDesign::sfLDPocock(a, t)$spend,
                `sfHSD(-10)` = hsd(-10), `sfHSD(-4)` = hsd(-4), `sfHSD(0)` = hsd(0), `sfHSD(1)` = hsd(1), `sfHSD(2)` = hsd(2),
                `sfPower(3)` = function(a, t) gsDesign::sfPower(a, t, 3)$spend, linear = function(a, t) a * pmin(t, 1))
rule_menu <- list(NULL, NULL, quote(r1), quote(r1 && r2), quote(r1 || r2), quote(r1 + r2 >= 1))
set.seed(as.integer(args[3])); rows <- list()
for (d in seq_len(as.integer(args[1]))) {
    m <- sample(2:5, 1); K <- sample(2:5, 1)
    first <- if (runif(1) < 0.15) 0.01 else 0.12
    base <- c(sort(round(runif(K - 1, first, 0.92), 3)), 1)
    while (any(diff(base) < 0.04)) base <- c(sort(round(runif(K - 1, first, 0.92), 3)), 1)
    info <- matrix(base, m, K, byrow = TRUE)
    if (runif(1) < 0.25) info[sample(m, 1), 1] <- NA
    if (runif(1) < 0.25) { i <- sample(m, 1); k <- sample(seq_len(K - 1), 1); info[i, k:K] <- 1 }
    sfk <- sample(names(sf_menu), m, replace = TRUE)
    look_back <- runif(m) < 0.4; alpha <- sample(c(0.025, 0.025, 0.05, 0.01, 0.2), 1); sum1 <- runif(1) < 0.8
    w <- rexp(m) * (runif(m) > 0.15); if (all(w == 0)) w[1] <- 1; w <- w / sum(w)
    G <- matrix(rexp(m * m) * (runif(m * m) > 0.2), m); diag(G) <- 0
    rs <- rowSums(G); for (i in seq_len(m)) G[i, ] <- if (rs[i] > 0) G[i, ] / rs[i] else { v <- rep(1, m); v[i] <- 0; v / (m - 1) }
    if (!sum1) G <- G * runif(m, 0.3, 1)
    rq <- rule_menu[[sample(length(rule_menu), 1)]]
    nul <- if (d %% 2 == 1) rep(TRUE, m) else { v <- runif(m) < 0.5; if (!any(v)) v[1] <- TRUE; v }
    delta <- ifelse(nul, 0, qnorm(0.9) + qnorm(1 - alpha))
    rho <- if (runif(1) < 0.5) { r <- matrix(runif(1, 0, 0.9), m, m); diag(r) <- 1; r } else cov2cor(crossprod(matrix(rnorm(m * (m + 2)), m + 2)))
    P <- sim_raw(nsim, delta, rho, info)
    pv <- tryCatch(transform_pvalues_gsd(P, info_frac = info, spending = unname(sf_menu[sfk]), alpha = alpha, look_back = look_back),
                   error = function(e) e)
    if (inherits(pv, "error")) {   # an analysis that spends nothing (entry C1): recorded and skipped
        rows[[d]] <- data.table(design = d, m = m, K = K, first_info = min(info, na.rm = TRUE), alpha = alpha, spending = paste(sfk, collapse = ","),
                                refused = substr(conditionMessage(pv), 1, 60))
        next
    }
    pk <- pkg_times(pv, w, G, rule = if (is.null(rq)) NULL else stopping_rule_gsd(!!rq), sum1 = sum1)
    fwer <- mean(rowSums(pk$times[, nul, drop = FALSE] > 0) > 0)
    se <- sqrt(alpha * (1 - alpha) / nsim)
    rows[[d]] <- data.table(design = d, m = m, K = K, first_info = min(info, na.rm = TRUE), alpha = alpha, nulls = sum(nul),
        global = all(nul), spending = paste(sfk, collapse = ","), look_back = paste(as.integer(look_back), collapse = ""),
        sum1 = sum1, rule = if (is.null(rq)) "none" else deparse(rq), fwer = fwer, z = (fwer - alpha) / se)
}
res <- rbindlist(rows, fill = TRUE); saveRDS(res, args[4])
if ("refused" %in% names(res)) { cat(sprintf("designs refused by the transform (entry C1): %d\n", sum(!is.na(res$refused)))); res <- res[is.na(refused)] }
cat(sprintf("designs %d (%d global nulls), %s trials each\n", nrow(res), sum(res$global), format(nsim, big.mark = ",")))
cat(sprintf("largest familywise error relative to alpha: %.4f at alpha %.3f (z = %.2f); designs above alpha + 3 SE: %d\n",
            res[which.max(z), fwer], res[which.max(z), alpha], max(res$z), sum(res$z > 3)))
print(res[, .(designs = .N, mean_ratio = round(mean(fwer / alpha), 3), max_z = round(max(z), 2)), by = .(alpha, global)][order(alpha, global)], row.names = FALSE)
print(res[order(-z)][1:5, .(design, m, K, alpha, nulls, spending, look_back, rule, fwer, z = round(z, 2))], row.names = FALSE)
