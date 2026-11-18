# fmt: skip file
# Stress test of the two fallbacks added to the table kernel before the merge (8ff1590, decbd86):
# ill-conditioned graphs (smallest update denominator below 1e-6) and near ties (within 1e-6 of a
# critical value). Also familywise error with the merged kernel, and the auto rule's boundary.
# Run: R_LIBS=<gsd-build-spending build> Rscript FS_fallbacks.R   (about 5 minutes; needs graphicalMCP, data.table, mvtnorm)
suppressMessages({ library(multigrain); library(data.table) })
suppressWarnings(requireNamespace("graphicalMCP"))
gs  <- multigrain:::graph_shortcut
gsp <- multigrain:::graph_shortcut_parallel
tab <- multigrain:::graph_shortcut_table
ker <- multigrain:::graph_shortcut_kernel
run <- function(kernel, f) withr::with_options(list(multigrain.shortcut_kernel = kernel), f())
res <- list()
note <- function(id, ok, what) {
    res[[id]] <<- isTRUE(ok)
    cat(sprintf("%-5s %-4s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", what))
}
rand_graph <- function(m, sum1 = TRUE, sparse = 0) {
    w <- rexp(m); w[runif(m) < sparse] <- 0; if (all(w == 0)) w[1] <- 1
    w <- w / sum(w); if (!sum1) w <- w * runif(1, 0.5, 1)
    G <- matrix(rexp(m * m), m); G[runif(m * m) < sparse] <- 0; diag(G) <- 0
    rs <- rowSums(G); G[rs > 0, ] <- G[rs > 0, ] / rs[rs > 0]
    if (!sum1) G <- G * runif(m, 0.5, 1)
    list(w = w, G = G)
}
# a graph whose pair (1, 2) is close to degenerate: g12 = g21 = 1 - e, the rest of rows 1 and 2 to H3
near_degenerate <- function(m, e) {
    g <- rand_graph(m); G <- g$G
    G[1, ] <- 0; G[2, ] <- 0; G[1, 2] <- 1 - e; G[2, 1] <- 1 - e; G[1, 3] <- e; G[2, 3] <- e
    list(w = g$w, G = G)
}
sim_p <- function(N, m, mu = 2.5, rho = 0.5) {
    S <- matrix(rho, m, m); diag(S) <- 1
    z <- mvtnorm::rmvnorm(N, rep(mu, m), S)
    matrix(pnorm(z, lower.tail = FALSE), N, m)
}
# graph update of Bretz et al. (2009) after removing k, written from the paper
remove_k <- function(a, G, k) {
    m <- length(a); a2 <- a + a[k] * G[k, ]; a2[k] <- 0
    G2 <- matrix(0, m, m)
    for (i in seq_len(m)) for (j in seq_len(m)) if (i != j && i != k && j != k) {
        d <- 1 - G[i, k] * G[k, i]
        G2[i, j] <- if (d != 0) (G[i, j] + G[i, k] * G[k, j]) / d else 0
    }
    list(a = a2, G = G2)
}

## FS9: ill-conditioned graphs either side of MIN_DENOM = 1e-6 (pair denominator d = 1 - (1 - e)^2, about 2e)
set.seed(909)
grid_e <- c(1e-2, 1e-4, 1e-5, 2e-6, 6e-7, 5e-7, 4e-7, 1e-8, 1e-12, 1e-15, 1.2e-16, 0)
rows9 <- list()
for (m in c(4, 8)) for (e in grid_e) for (rep in 1:3) {
    g <- near_degenerate(m, e)
    md <- attr(tab(0.025, g$w, g$G), "min_denom")
    crit <- tab(0.025, g$w, g$G)
    p <- sim_p(3000, m, mu = 2)
    # half the trials get one p-value placed on a critical value of a random set, nudged by up to 1e-7
    for (r in sample(3000, 1500)) {
        S <- sample(1:(2^m - 1), 1); inS <- bitwAnd(S, 2^(0:(m - 1))) > 0; l <- sample(which(inS), 1)
        p[r, !inS] <- 0; p[r, l] <- crit[S + 1, l] * (1 + sample(c(-1, 1), 1) * 10^runif(1, -16, -7))
    }
    a <- run("sequential", function() gs(p, 0.025, g$w, g$G))
    b <- run("table", function() gs(p, 0.025, g$w, g$G))
    c2 <- run("table", function() gsp(p, 0.025, g$w, g$G, num_threads = 2))
    rows9[[length(rows9) + 1]] <- data.table(m = m, e = e, min_denom = md, uses_table = md >= 1e-6,
                                             mismatch = sum(rowSums(a != b) > 0) + sum(rowSums(a != c2) > 0))
}
r9 <- rbindlist(rows9)
print(r9[, .(graphs = .N, min_denom = signif(min(min_denom), 3), table_used = sum(uses_table), mismatching_trials = sum(mismatch)), by = .(m, e)], row.names = FALSE)
note("FS9", sum(r9$mismatch) == 0, sprintf("ill-conditioned graphs, e from 1e-2 to 0, m = 4 and 8: table, 2 threads and sequential agree on all %d x 3,000 trials", nrow(r9)))

## FS10: does min_denom lead to the same kernel choice as every denominator the sequential kernel divides a non-zero entry by?
## Independent enumeration in R over every set of 3 or more hypotheses and every removal from it.
set.seed(1010)
viol <- 0; n10 <- 0; reldiff <- 0
for (rep in 1:300) {
    m <- sample(3:7, 1)
    g <- switch(rep %% 4 + 1, rand_graph(m), rand_graph(m, sum1 = FALSE, sparse = 0.4),
                near_degenerate(m, 10^runif(1, -9, -2)),
                { h <- rand_graph(m); h$G[h$G < 0.15] <- 0; h })   # small edges zeroed without renormalising
    md <- attr(tab(0.025, g$w, g$G), "min_denom")
    dmin <- Inf
    for (S in 1:(2^m - 1)) {
        inS <- bitwAnd(S, 2^(0:(m - 1))) > 0
        if (sum(inS) < 3) next
        st <- list(a = g$w, G = g$G)
        for (k in which(!inS)) st <- remove_k(st$a, st$G, k)
        for (k in which(inS)) for (i in setdiff(which(inS), k)) {
            js <- setdiff(which(inS), c(i, k))
            if (any(st$G[i, js] + st$G[i, k] * st$G[k, js] != 0)) dmin <- min(dmin, 1 - st$G[i, k] * st$G[k, i])
        }
    }
    n10 <- n10 + 1
    if (is.finite(dmin)) reldiff <- max(reldiff, abs(md - dmin) / dmin)
    if ((md >= 1e-6) != (dmin >= 1e-6)) viol <- viol + 1      # the two disagree on which kernel to use
}
note("FS10", viol == 0, sprintf("min_denom gives the same kernel choice as an independent enumeration of every denominator applied to a non-zero entry: %d of %d graphs disagree; largest relative difference %.2g (rounding: R divides, the kernel multiplies by the reciprocal)", viol, n10, reldiff))

## FS11: near ties in graphs that use the table (d between 1.1e-6 and 1e-3). Probes at c(S) * (1 + r), where
## c(S) is computed in R by removing the other hypotheses in a random order (the table removes them in index order).
set.seed(1111)
n11 <- 0; bad11 <- 0; gap <- numeric(0)
for (rep in 1:150) {
    m <- sample(4:9, 1)
    g <- near_degenerate(m, 10^runif(1, log10(5.5e-7), -3.3))
    if (attr(tab(0.025, g$w, g$G), "min_denom") < 1e-6) next
    crit <- tab(0.025, g$w, g$G)
    P <- NULL
    for (q in 1:40) {
        S <- sample(1:(2^m - 2), 1); inS <- bitwAnd(S, 2^(0:(m - 1))) > 0
        st <- list(a = 0.025 * g$w, G = g$G)
        out <- which(!inS); for (k in out[sample.int(length(out))]) st <- remove_k(st$a, st$G, k)   # sample.int: sample(x) of a single number x would permute 1:x
        l <- sample(which(inS), 1)
        gap <- c(gap, abs(st$a[l] - crit[S + 1, l]) / crit[S + 1, l])
        for (r in c(-1e-6, -1e-7, -1e-9, -1e-12, 0, 1e-12, 1e-9, 1e-7, 1e-6)) {
            p <- rep(0.9, m); p[!inS] <- 0; p[l] <- st$a[l] * (1 + r); P <- rbind(P, p)
        }
    }
    a <- run("sequential", function() gs(P, 0.025, g$w, g$G))
    b <- run("table", function() gs(P, 0.025, g$w, g$G))
    n11 <- n11 + nrow(P); bad11 <- bad11 + sum(rowSums(a != b) > 0)
}
note("FS11", bad11 == 0, sprintf("near-tie probes in table-kernel graphs: %d of %d disagree; largest relative gap between the R and table critical values %.2g", bad11, n11, max(gap[is.finite(gap)])))

## FS12: familywise error with the merged kernel (calc_power_pvals(), auto kernel), global null and partial nulls
set.seed(1212)
rows12 <- list()
for (rep in 1:24) {
    m <- sample(3:10, 1); rho <- sample(c(0, 0.5, 0.9), 1)
    g <- rand_graph(m, sum1 = rep %% 2 == 0, sparse = if (rep %% 3 == 0) 0.3 else 0)
    nul <- if (rep <= 12) rep(TRUE, m) else sample(c(TRUE, FALSE), m, replace = TRUE)
    if (!any(nul)) nul[1] <- TRUE
    S <- matrix(rho, m, m); diag(S) <- 1
    z <- mvtnorm::rmvnorm(2e5, ifelse(nul, 0, 3), S)
    p <- matrix(pnorm(z, lower.tail = FALSE), ncol = m)
    rej <- gs(p, 0.025, g$w, g$G)
    fwer <- mean(rowSums(rej[, nul, drop = FALSE]) > 0)
    rows12[[rep]] <- data.table(m = m, rho = rho, nulls = sum(nul), kernel = ker(2e5L, m), fwer = fwer)
}
r12 <- rbindlist(rows12)
se <- sqrt(0.025 * 0.975 / 2e5)
cat(sprintf("      largest familywise error %.4f (alpha 0.025, standard error %.5f); kernels used: %s\n", max(r12$fwer), se,
            paste(r12[, .N, by = kernel][, paste(kernel, N)], collapse = ", ")))
note("FS12", all(r12$fwer <= 0.025 + 3 * se), sprintf("familywise error on 24 designs (12 global nulls, 12 partial), 200,000 trials each: none above alpha + 3 standard errors"))

## FS13: the auto rule at its boundary 2^m = 2 N, and the same rejections either side
set.seed(1313)
ok13 <- TRUE; lines13 <- character(0)
for (m in c(6, 10, 14)) {
    N0 <- 2^(m - 1); g <- rand_graph(m); p <- sim_p(N0 + 1, m)
    k <- c(ker(as.integer(N0 - 1), m), ker(as.integer(N0), m))
    a <- gs(p[seq_len(N0 - 1), ], 0.025, g$w, g$G); b <- gs(p[seq_len(N0), ], 0.025, g$w, g$G)
    ok13 <- ok13 && identical(k, c("sequential", "table")) && identical(a, b[seq_len(N0 - 1), ])
    lines13 <- c(lines13, sprintf("m = %d: %s for %d trials, %s for %d", m, k[1], N0 - 1, k[2], N0))
}
note("FS13", ok13, paste("auto rule switches at 2^m = 2N with the same rejections:", paste(lines13, collapse = "; ")))

## FS14: graphicalMCP on ill-conditioned graphs that still use the table (d near 1.1e-6)
set.seed(1414)
bad14 <- 0; n14 <- 0
for (rep in 1:40) {
    m <- sample(3:6, 1); g <- near_degenerate(m, 10^runif(1, log10(5.5e-7), -5))
    if (attr(tab(0.025, g$w, g$G), "min_denom") < 1e-6) next
    p <- sim_p(60, m, mu = 2.2)
    b <- run("table", function() gs(p, 0.025, g$w, g$G))
    gr <- graphicalMCP::graph_create(g$w, g$G)
    ref <- t(apply(p, 1, function(pp) graphicalMCP::graph_test_shortcut(gr, pp, alpha = 0.025)$outputs$rejected))
    n14 <- n14 + 1; if (!all(unname(ref) == unname(b))) bad14 <- bad14 + 1
}
note("FS14", bad14 == 0, sprintf("table kernel = graphicalMCP::graph_test_shortcut() on %d near-degenerate graphs that still use the table (d from 1.1e-6 to 2e-5) x 60 trials; mismatching graphs: %d", n14, bad14))

cat(sprintf("\n%d of %d checks passed\n", sum(unlist(res)), length(res)))
