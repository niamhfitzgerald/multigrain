# fmt: skip file
# D2: the package against the independent reference (ref_lib.R), trial by trial, on random designs.
# Usage: R_LIBS=<build> Rscript D2_reference.R <n_designs> <nsim> <seed> <out.rds>
args <- commandArgs(TRUE); n_des <- as.integer(args[1]); nsim <- as.integer(args[2]); seed <- as.integer(args[3])
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "ref_lib.R"))
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
sf_menu <- list(
    OF     = list(f = function(a, t) gsDesign::sfLDOF(a, t)$spend, label = "sfLDOF"),
    Pocock = list(f = function(a, t) gsDesign::sfLDPocock(a, t)$spend, label = "sfLDPocock"),
    HSDm4  = list(f = function(a, t) gsDesign::sfHSD(a, t, -4)$spend, label = "sfHSD(-4)"),
    HSDm2  = list(f = function(a, t) gsDesign::sfHSD(a, t, -2)$spend, label = "sfHSD(-2)"),
    HSD0   = list(f = function(a, t) gsDesign::sfHSD(a, t, 0)$spend, label = "sfHSD(0)"),
    HSD1   = list(f = function(a, t) gsDesign::sfHSD(a, t, 1)$spend, label = "sfHSD(1)"),
    Pow3   = list(f = function(a, t) gsDesign::sfPower(a, t, 3)$spend, label = "sfPower(3)"),
    Linear = list(f = function(a, t) a * pmin(t, 1), label = "linear")
)
rules <- list(function(m) NULL, function(m) NULL,
              function(m) list(q = quote(r1), f = function(r) r[1]),
              function(m) list(q = quote(r1 && r2), f = function(r) r[1] && r[2]),
              function(m) list(q = quote(r1 || r2), f = function(r) r[1] || r[2]),
              function(m) list(q = quote(r1 + r2 >= 2), f = function(r) r[1] + r[2] >= 2),
              function(m) list(q = quote(r2 && !r1), f = function(r) r[2] && !r[1]))
set.seed(seed)
rows <- list()
for (d in seq_len(n_des)) {
    m <- sample(2:4, 1); K <- sample(2:4, 1)
    base <- c(sort(round(runif(K - 1, 0.15, 0.9), 3)), 1)
    while (any(diff(base) < 0.05)) base <- c(sort(round(runif(K - 1, 0.15, 0.9), 3)), 1)
    info <- matrix(base, m, K, byrow = TRUE)
    kind <- sample(c("common", "common", "late_start", "early_mature"), 1)
    if (kind == "late_start") info[sample(m, 1), 1] <- NA
    if (kind == "early_mature") { i <- sample(m, 1); k <- sample(seq_len(K - 1), 1); info[i, k:K] <- 1 }
    sfk <- sample(names(sf_menu), m, replace = TRUE)
    sfs <- lapply(sf_menu[sfk], `[[`, "f")
    look_back <- runif(m) < 0.4
    alpha <- sample(c(0.025, 0.05, 0.01), 1)
    sum1 <- runif(1) < 0.8
    w <- rexp(m) * (runif(m) > 0.15); if (all(w == 0)) w[1] <- 1; w <- w / sum(w)
    G <- matrix(rexp(m * m) * (runif(m * m) > 0.2), m); diag(G) <- 0
    rs <- rowSums(G); for (i in seq_len(m)) G[i, ] <- if (rs[i] > 0) G[i, ] / rs[i] else { v <- rep(1, m); v[i] <- 0; v / (m - 1) }
    if (!sum1) G <- G * runif(m, 0.3, 1)
    rl <- rules[[sample(length(rules), 1)]](m)
    delta <- qnorm(sample(c(0.3, 0.6, 0.8, 0.95), m, replace = TRUE)) + qnorm(1 - alpha)
    rho <- matrix(runif(1, 0, 0.8), m, m); diag(rho) <- 1
    P <- sim_raw(nsim, delta, rho, info)
    pv <- transform_pvalues_gsd(P, info_frac = info, spending = sfs, alpha = alpha, look_back = look_back)
    pk <- pkg_times(pv, w, G, rule = if (is.null(rl)) NULL else stopping_rule_gsd(!!rl$q), sum1 = sum1)
    rf <- ref_gsd(P, info, sfs, alpha, w, G, look_back, rule = if (is.null(rl)) NULL else rl$f)
    mis <- rowSums(pk$times != rf$times) > 0
    rows[[d]] <- data.table(design = d, m = m, K = K, kind = kind, alpha = alpha, sum1 = sum1,
        spending = paste(sapply(sf_menu[sfk], `[[`, "label"), collapse = ","), look_back = paste(as.integer(look_back), collapse = ""),
        rule = if (is.null(rl)) "none" else deparse(rl$q), calls = pk$n, mismatches = sum(mis),
        max_near_mismatch = if (any(mis)) max(rf$near[mis]) else NA_real_,
        local_power_ok = isTRUE(all.equal(unname(pk$out$local_power), unname(colMeans(pk$times > 0)))),
        rejections = mean(rowSums(rf$times > 0)))
    if (any(mis)) attr(rows[[d]], "example") <- list(P = P[which(mis)[1], , , drop = FALSE], pkg = pk$times[which(mis)[1], ], ref = rf$times[which(mis)[1], ])
}
res <- rbindlist(rows)
saveRDS(list(res = res, examples = lapply(rows, attr, "example")), args[4])
cat(sprintf("designs %d, trials %d, trials whose decision times differ: %d (%.2g%%)\n", nrow(res), sum(res$calls),
            sum(res$mismatches), 100 * sum(res$mismatches) / sum(res$calls)))
cat("largest relative distance to a boundary in a differing trial:", signif(max(res$max_near_mismatch, na.rm = TRUE), 3), "\n")
cat("every trial recorded once:", all(res$calls == nsim), "  local_power agrees with the recorded times:", all(res$local_power_ok), "\n")
print(res[, .(designs = .N, trials = sum(calls), mismatches = sum(mismatches)), by = .(kind)], row.names = FALSE)
print(res[, .(designs = .N, mismatches = sum(mismatches)), by = .(rule)], row.names = FALSE)
