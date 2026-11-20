# fmt: skip file
# D3: repeated p-values against exact ones. The exact repeated p-value of a raw p-value p at analysis k is the level a
# at which the nominal boundary c_k(a) from gsDesign::gsBound1() equals p, found by uniroot() on log a. Also records
# the sign of each error: a package value below the exact one is anti-conservative.
# Usage: R_LIBS=<build> Rscript D3_transform.R <n_designs> <seed> <out.rds>
args <- commandArgs(TRUE)
source(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "ref_lib.R"))
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
sf_menu <- list(sfLDOF = function(a, t) gsDesign::sfLDOF(a, t)$spend, sfLDPocock = function(a, t) gsDesign::sfLDPocock(a, t)$spend,
                `sfHSD(-4)` = function(a, t) gsDesign::sfHSD(a, t, -4)$spend, `sfHSD(1)` = function(a, t) gsDesign::sfHSD(a, t, 1)$spend,
                `sfHSD(-10)` = function(a, t) gsDesign::sfHSD(a, t, -10)$spend, `sfPower(3)` = function(a, t) gsDesign::sfPower(a, t, 3)$spend,
                linear = function(a, t) a * pmin(t, 1))
exact_rep <- function(p, sf, t, k, alpha) {          # exact repeated p-value, NA when above alpha
    f <- function(la) log(boundary(sf, exp(la), t)[k]) - log(p)
    lo <- log(1e-14); hi <- log(alpha)
    if (f(hi) < 0) return(NA_real_); if (f(lo) > 0) return(1e-14)
    exp(uniroot(f, c(lo, hi), tol = 1e-13)$root)
}
set.seed(as.integer(args[2])); rows <- list()
for (d in seq_len(as.integer(args[1]))) {
    K <- sample(2:5, 1); t <- c(sort(round(runif(K - 1, 0.05, 0.92), 3)), 1)
    while (any(diff(t) < 0.04)) t <- c(sort(round(runif(K - 1, 0.05, 0.92), 3)), 1)
    sfn <- sample(names(sf_menu), 1); sf <- sf_menu[[sfn]]
    alpha <- sample(c(0.025, 0.05, 0.2, 1e-3, 1e-4), 1); grid <- sample(c(64L, 256L, 1024L), 1)
    # raw p-values spread on a log scale under each analysis's boundary at alpha
    cb <- boundary(sf, alpha, t)
    P <- array(NA_real_, c(12, 1, K))
    for (k in seq_len(K)) P[, 1, k] <- exp(runif(12, log(cb[k] * 1e-6), log(cb[k] * 0.999)))
    pv <- tryCatch(transform_pvalues_gsd(P, info_frac = t, spending = sf, alpha = alpha, grid_size = grid), error = function(e) e)
    if (inherits(pv, "error")) { rows[[d]] <- data.table(design = d, K = K, sf = sfn, alpha = alpha, grid = grid, error = conditionMessage(pv)); next }
    for (k in seq_len(K)) for (s in 1:12) {
        ex <- exact_rep(P[s, 1, k], sf, t, k, alpha); pk <- pv$pvals[s, 1, k]
        rows[[length(rows) + 1]] <- data.table(design = d, K = K, k = k, t_k = t[k], sf = sfn, alpha = alpha, grid = grid,
                                               p = P[s, 1, k], exact = ex, pkg = pk, rel = (pk - ex) / ex, error = NA_character_)
    }
}
res <- rbindlist(rows, fill = TRUE)
saveRDS(res, args[3])
ok <- res[is.na(error) & !is.na(exact)]
cat(sprintf("designs %d, repeated p-values compared %d, transform errors %d\n", uniqueN(res$design), nrow(ok), uniqueN(res[!is.na(error), design])))
print(ok[, .(n = .N, median_abs_rel = signif(median(abs(rel)), 2), max_abs_rel = signif(max(abs(rel)), 2),
             share_below_exact = round(mean(rel < -1e-12), 2), most_negative = signif(min(rel), 2)), by = grid][order(grid)], row.names = FALSE)
print(ok[, .(n = .N, max_abs_rel = signif(max(abs(rel)), 2), most_negative = signif(min(rel), 2)), by = .(alpha)][order(alpha)], row.names = FALSE)
print(ok[, .(n = .N, max_abs_rel = signif(max(abs(rel)), 2), most_negative = signif(min(rel), 2)), by = .(first = k == 1)], row.names = FALSE)
if (any(!is.na(res$error))) print(unique(res[!is.na(error), .(sf, alpha, grid, K, error = substr(error, 1, 120))]))
# for entry C4: the same errors by raw p-value band and analysis
ok[, band := fifelse(p >= 1e-12, "raw p >= 1e-12", fifelse(k == 1, "raw p < 1e-12, first analysis", "raw p < 1e-12, later analyses"))]
cat("by raw p-value band (for C4):\n")
print(ok[, .(n = .N, max_abs_rel = signif(max(abs(rel)), 2), most_negative = signif(min(rel), 2)), by = .(band, grid)][order(band, grid)], row.names = FALSE)
