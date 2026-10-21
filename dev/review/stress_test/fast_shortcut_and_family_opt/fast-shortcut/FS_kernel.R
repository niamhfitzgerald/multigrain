# fmt: skip file
# Stress test of the table kernel on fast-shortcut (62bba6a).
# Run: R_LIBS=<fast-shortcut build> Rscript FS_kernel.R
suppressMessages(library(multigrain))
gs  <- multigrain:::graph_shortcut
gsp <- multigrain:::graph_shortcut_parallel
tab <- multigrain:::graph_shortcut_table
ker <- multigrain:::graph_shortcut_kernel
run <- function(kernel, f) withr::with_options(list(multigrain.shortcut_kernel = kernel), f())

rand_graph <- function(m, sum1 = TRUE, sparse = 0) {
    w <- rexp(m); w[runif(m) < sparse] <- 0; if (all(w == 0)) w[1] <- 1
    w <- w / sum(w); if (!sum1) w <- w * runif(1, 0.5, 1)
    G <- matrix(rexp(m * m), m); G[runif(m * m) < sparse] <- 0; diag(G) <- 0
    rs <- rowSums(G); G[rs > 0, ] <- G[rs > 0, ] / rs[rs > 0]
    if (!sum1) G <- G * runif(m, 0.5, 1)
    list(w = w, G = G)
}
sim_p <- function(N, m, mu = 2.5, rho = 0.5) {
    S <- matrix(rho, m, m); diag(S) <- 1
    z <- MASS::mvrnorm(N, rep(mu, m), S)
    matrix(pnorm(z, lower.tail = FALSE), N, m)
}
res <- list()
note <- function(id, ok, what) {
    res[[id]] <<- isTRUE(ok)
    cat(sprintf("%-5s %-4s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", what))
}

## FS1: random graphs, m = 2 to 14, full and partial row sums, sparse graphs
set.seed(101)
n_case <- 0; n_bad <- 0; bad <- NULL
for (m in 2:14) for (rep in 1:12) {
    g <- rand_graph(m, sum1 = rep %% 2 == 0, sparse = if (rep %% 3 == 0) 0.4 else 0)
    p <- sim_p(1500, m, mu = runif(1, 1, 3.5))
    a <- run("sequential", function() gs(p, 0.025, g$w, g$G))
    b <- run("table", function() gs(p, 0.025, g$w, g$G))
    c2 <- run("table", function() gsp(p, 0.025, g$w, g$G, num_threads = 2))
    n_case <- n_case + 1
    if (!identical(a, b) || !identical(a, c2)) { n_bad <- n_bad + 1; bad <- c(bad, sprintf("m%d_r%d", m, rep)) }
}
note("FS1", n_bad == 0, sprintf("table = sequential (serial and 2 threads) on %d random graphs, m 2-14, 1500 trials each; mismatches: %d %s", n_case, n_bad, paste(bad, collapse = " ")))

## FS2: p-values on a 4-decimal grid (as from a trial report), weights with thirds
set.seed(202)
n_bad2 <- 0; n_row2 <- 0; ex2 <- NULL
for (rep in 1:300) {
    m <- sample(3:8, 1)
    w <- rep(1 / m, m); G <- matrix(1 / (m - 1), m, m); diag(G) <- 0
    if (rep %% 2 == 0) { g <- rand_graph(m); w <- round(g$w, 2); w <- w / sum(w); G <- g$G }
    alpha <- sample(c(0.025, 0.05, 0.01), 1)
    p <- matrix(round(runif(400 * m, 0, 3 * alpha), 4), ncol = m)
    a <- run("sequential", function() gs(p, alpha, w, G))
    b <- run("table", function() gs(p, alpha, w, G))
    d <- rowSums(a != b) > 0
    n_row2 <- n_row2 + sum(d)
    if (any(d)) { n_bad2 <- n_bad2 + 1; if (is.null(ex2)) ex2 <- list(p = p[which(d)[1], ], w = w, G = G, alpha = alpha, seq = a[which(d)[1], ], tab = b[which(d)[1], ]) }
}
note("FS2", n_bad2 == 0, sprintf("p-values rounded to 4 decimals (300 cases x 400 trials): cases with a mismatch %d, trials %d", n_bad2, n_row2))
if (!is.null(ex2)) { cat("      first mismatch: p =", ex2$p, " alpha =", ex2$alpha, "\n      w =", signif(ex2$w, 6), "\n      sequential rejects", which(ex2$seq), "| table rejects", which(ex2$tab), "\n"); saveRDS(ex2, "FS2_example.rds") }

## FS3: p-values set exactly at the table's critical value of every set S
## (the set reached by removing hypotheses in increasing index order)
set.seed(303)
n_bad3 <- 0; tried3 <- 0; ex3 <- NULL
for (rep in 1:200) {
    m <- sample(3:7, 1)
    g <- rand_graph(m, sum1 = rep %% 2 == 0)
    crit <- tab(0.025, g$w, g$G)
    for (S in sample(1:(2^m - 2), min(20, 2^m - 2))) {
        inS <- bitwAnd(S, 2^(0:(m - 1))) > 0
        for (l in which(inS)) {
            p <- rep(0.9, m)
            p[!inS] <- 0                     # hypotheses outside S get rejected first
            p[l] <- crit[S + 1, l]           # exactly at the table's level for S
            P <- matrix(p, 1)
            a <- run("sequential", function() gs(P, 0.025, g$w, g$G))
            b <- run("table", function() gs(P, 0.025, g$w, g$G))
            tried3 <- tried3 + 1
            if (!identical(a, b)) { n_bad3 <- n_bad3 + 1; if (is.null(ex3)) ex3 <- list(w = g$w, G = g$G, p = p, seq = a, tab = b) }
        }
    }
}
note("FS3", n_bad3 == 0, sprintf("p exactly at a table critical value after other rejections: %d of %d probes disagree", n_bad3, tried3))
if (!is.null(ex3)) { cat("      first: m =", length(ex3$p), " sequential rejects", which(ex3$seq), "| table rejects", which(ex3$tab), "\n"); saveRDS(ex3, "FS3_example.rds") }

## FS4: independent reference (graphicalMCP::graph_test_shortcut), m 2 to 8
set.seed(404)
n_bad4 <- 0; n4 <- 0
for (rep in 1:60) {
    m <- sample(2:8, 1); g <- rand_graph(m, sum1 = rep %% 2 == 0)
    p <- sim_p(50, m, mu = 2.5)
    b <- run("table", function() gs(p, 0.025, g$w, g$G))
    gr <- graphicalMCP::graph_create(g$w, g$G)
    ref <- t(apply(p, 1, function(pp) graphicalMCP::graph_test_shortcut(gr, pp, alpha = 0.025)$outputs$rejected))
    n4 <- n4 + 1
    if (!all(unname(ref) == unname(b))) n_bad4 <- n_bad4 + 1
}
note("FS4", n_bad4 == 0, sprintf("table kernel = graphicalMCP::graph_test_shortcut() on %d graphs x 50 trials; mismatching graphs: %d", n4, n_bad4))

## FS5: awkward inputs
cases <- list(
    "g12 = g21 = 1 (degenerate denominator)" = list(w = c(.5, .5, 0), G = matrix(c(0,1,0, 1,0,0, .5,.5,0), 3, byrow = TRUE)),
    "all weight on a node with no out-edges"  = list(w = c(1, 0, 0), G = matrix(0, 3, 3)),
    "epsilon edges 1e-15"                      = list(w = c(1, 0, 0), G = matrix(c(0,1-1e-15,1e-15, 1e-15,0,1-1e-15, .5,.5,0), 3, byrow = TRUE)),
    "zero graph, zero weights"                 = list(w = c(0, 0, 0), G = matrix(0, 3, 3))
)
ok5 <- TRUE
for (nm in names(cases)) {
    g <- cases[[nm]]
    p <- rbind(sim_p(300, 3), c(0, 0, 0), c(1, 1, 1), c(NA, 0.001, 0.001), c(0.0125, 0.0125, 0.0125))
    a <- run("sequential", function() gs(p, 0.025, g$w, g$G))
    b <- run("table", function() gs(p, 0.025, g$w, g$G))
    if (!identical(a, b)) { ok5 <- FALSE; cat("      differs:", nm, "\n") }
}
note("FS5", ok5, "degenerate graphs, zero weights, epsilon edges, p = 0, 1, NA and exact ties: kernels agree")

## FS6: the kernel depends on the number of trials; the rejections must not
set.seed(606)
m <- 12; g <- rand_graph(m); p <- sim_p(20000, m)
k_small <- ker(100L, m); k_big <- ker(20000L, m)
a <- gs(p[1:100, ], 0.025, g$w, g$G); b <- gs(p, 0.025, g$w, g$G)[1:100, ]
note("FS6", identical(a, b) && k_small != k_big, sprintf("m = 12: %s kernel for 100 trials, %s for 20,000; the first 100 rows agree: %s", k_small, k_big, identical(a, b)))

## FS7: the largest sizes
t_tab <- system.time(crit20 <- tab(0.025, rep(1 / 20, 20), { G <- matrix(1 / 19, 20, 20); diag(G) <- 0; G }))[["elapsed"]]
note("FS7a", nrow(crit20) == 2^20, sprintf("m = 20: table of %d x %d (%.0f MB) built in %.1f s", nrow(crit20), ncol(crit20), object.size(crit20) / 2^20, t_tab))
rm(crit20); invisible(gc())
e21 <- tryCatch(run("table", function() gs(matrix(0.5, 2, 21), 0.025, rep(1 / 21, 21), matrix(0, 21, 21))), error = conditionMessage)
note("FS7b", is.character(e21), paste("m = 21 with the table kernel forced:", e21))
cat(sprintf("      auto kernel for m = 20: %s with 1e5 trials, %s with 6e5 trials\n", ker(100000L, 20L), ker(600000L, 20L)))

## FS8: option values
bad_opts <- list(list(multigrain.shortcut_kernel = "Table"), list(multigrain.shortcut_kernel = c("auto", "table")),
                 list(multigrain.shortcut_kernel = NA_character_), list(multigrain.shortcut_table_max_m = 2.5),
                 list(multigrain.shortcut_table_max_m = -1), list(multigrain.shortcut_table_max_m = "10"), list(multigrain.shortcut_table_max_m = 21))
msgs <- vapply(bad_opts, function(o) tryCatch(withr::with_options(o, { gs(matrix(0.01, 2, 2), 0.025, c(.5, .5), matrix(c(0, 1, 1, 0), 2)); "accepted" }), error = conditionMessage), "")
for (i in seq_along(bad_opts)) cat(sprintf("      %-40s -> %s\n", deparse(bad_opts[[i]][[1]]), msgs[i]))
note("FS8", !any(msgs == "accepted"), "invalid option values are refused")

cat(sprintf("\n%d of %d checks passed\n", sum(unlist(res)), length(res)))
