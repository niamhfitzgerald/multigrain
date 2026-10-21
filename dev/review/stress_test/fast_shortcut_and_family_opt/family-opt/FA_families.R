# fmt: skip file
# Stress test of graphs of families of hypotheses on family-opt (851f58e).
# Run: R_LIBS=<family-opt build> Rscript FA_families.R
suppressMessages(library(multigrain))
options(warn = 1)
res <- list()
note <- function(id, ok, what) {
    res[[id]] <<- isTRUE(ok)
    cat(sprintf("%-5s %-4s %s\n", id, if (isTRUE(ok)) "PASS" else "FAIL", what))
}
mvp <- function(N, mu, R) {          # one-sided p-values from correlated normals
    z <- MASS::mvrnorm(N, mu, R)
    matrix(pnorm(z, lower.tail = FALSE), N, length(mu))
}
exch <- function(m, rho) { R <- matrix(rho, m, m); diag(R) <- 1; R }
famR <- function(members, rho_in, rho_out) {   # correlation rho_in within, rho_out between families
    m <- sum(lengths(members)); f <- rep(seq_along(members), lengths(members))[order(unlist(members))]
    R <- outer(f, f, function(a, b) ifelse(a == b, rho_in, rho_out)); diag(R) <- 1; R
}

# An independent version of the procedure of Maurer and Bretz (2014), written
# from the help page: weighted Bonferroni over families, the within-family test
# at the family's level, weight passed on only when a family is fully rejected.
ref_trial <- function(p, members, test, alpha, w, G) {
    M <- length(members); a <- alpha * w; alive <- rep(TRUE, M)
    adj <- lapply(seq_len(M), function(f) p.adjust(p[members[[f]]], test[f]))
    repeat {
        done <- which(alive & vapply(seq_len(M), function(f) all(adj[[f]] < a[f]), NA))
        if (!length(done)) break
        f <- done[1]; alive[f] <- FALSE
        for (j in which(alive)) a[j] <- a[j] + a[f] * G[f, j]
        a[f] <- 0
        G2 <- G
        for (i in which(alive)) for (j in which(alive)) if (i != j) {
            d <- 1 - G[i, f] * G[f, i]
            G2[i, j] <- if (d > 0) (G[i, j] + G[i, f] * G[f, j]) / d else 0
        }
        G2[f, ] <- 0; G2[, f] <- 0; G <- G2
    }
    rej <- logical(length(p))
    for (f in seq_len(M)) rej[members[[f]]] <- if (!alive[f]) TRUE else adj[[f]] < a[f]
    rej
}
rand_graph <- function(M) {
    w <- rexp(M); w <- w / sum(w)
    G <- matrix(rexp(M * M), M); diag(G) <- 0; G <- G / rowSums(G)
    if (M == 1) G <- matrix(0, 1, 1)
    list(w = w, G = G)
}
rand_members <- function(m, M) {
    f <- c(seq_len(M), sample(M, m - M, replace = TRUE))[sample(m)]
    lapply(seq_len(M), function(k) which(f == k))
}
fam_rej <- function(p, fs, w, G, alpha = 0.025) {
    pw <- calc_power_pvals(p, w, G, alpha = alpha, families = fs, custom_power = list(
        all = trial_success(!!str2lang(paste0("1 * r", seq_len(ncol(p)), collapse = " + ")), verbose = "silent")))
    pw
}
kern <- function(p, fs, w, G, alpha = 0.025) {
    idx <- multigrain:::family_spec_get_index(fs) - 1L
    pa <- multigrain:::.prepare_pvals(p, fs)
    multigrain:::graph_shortcut_families(pa, idx, alpha, w, G)
}

## FA1: the kernel against the independent version, including ties and rounded p-values
set.seed(11)
n_bad <- 0; n_case <- 0; first <- NULL
for (rep in 1:120) {
    m <- sample(2:9, 1); M <- sample(1:min(m, 5), 1)
    mem <- rand_members(m, M); test <- sample(c("hommel", "hochberg", "holm"), M, TRUE)
    fs <- family_spec(mem, test = test); g <- rand_graph(M)
    p <- mvp(200, rep(2.2, m), exch(m, 0.5))
    if (rep %% 3 == 0) p <- round(p, 3)                         # many exact ties
    if (rep %% 5 == 0) p[, mem[[1]]] <- p[, mem[[1]][1]]        # equal p-values within a family
    k <- kern(p, fs, g$w, g$G)
    r <- t(apply(p, 1, ref_trial, members = fs$members, test = unname(fs$test), alpha = 0.025, w = g$w, G = g$G))
    n_case <- n_case + 1
    if (!all(unname(k) == unname(r))) { n_bad <- n_bad + 1; if (is.null(first)) first <- rep }
}
note("FA1", n_bad == 0, sprintf("kernel = independent version on %d random cases x 200 trials (with ties); mismatching cases: %d", n_case, n_bad))

## FA2: familywise error under the global null (200,000 trials)
set.seed(22)
layouts <- list("1 | 2-4 | 5" = list(1, 2:4, 5), "1-2 | 3-6" = list(1:2, 3:6), "1-6" = list(1:6))
N <- 2e5; worst <- 0; lines <- character()
for (lay in names(layouts)) for (rho in c(0, 0.5, 0.9)) {
    mem <- layouts[[lay]]; M <- length(mem); m <- sum(lengths(mem))
    p <- mvp(N, rep(0, m), famR(mem, rho, rho / 2))
    g <- list(w = rep(1 / M, M), G = if (M > 1) { G <- matrix(1 / (M - 1), M, M); diag(G) <- 0; G } else matrix(0, 1, 1))
    for (tst in c("hommel", "hochberg", "holm")) {
        fwer <- mean(rowSums(kern(p, family_spec(mem, test = tst), g$w, g$G)) > 0)
        worst <- max(worst, (fwer - 0.025) / sqrt(0.025 * 0.975 / N))
        lines <- c(lines, sprintf("      %-12s rho %.1f  %-8s FWER %.4f", lay, rho, tst, fwer))
    }
}
cat(lines, sep = "\n")
note("FA2", worst < 3, sprintf("global null, 27 designs: FWER within 3 SE of 0.025 or below (largest excess %.1f SE)", worst))

## FA3: familywise error under partial nulls (false hypotheses with large effects)
set.seed(33)
worst3 <- 0; out3 <- character()
for (rep in 1:24) {
    m <- 6; M <- sample(2:4, 1); mem <- rand_members(m, M); g <- rand_graph(M)
    false <- sample(m, sample(1:4, 1)); mu <- rep(0, m); mu[false] <- 4
    tst <- sample(c("hommel", "hochberg", "holm"), 1)
    p <- mvp(1e5, mu, famR(mem, 0.6, 0.3))
    k <- kern(p, family_spec(mem, test = tst), g$w, g$G)
    fwer <- mean(rowSums(k[, -false, drop = FALSE]) > 0)
    worst3 <- max(worst3, (fwer - 0.025) / sqrt(0.025 * 0.975 / 1e5))
}
note("FA3", worst3 < 3, sprintf("24 random partial-null designs, 1e5 trials each: largest excess over 0.025 is %.1f SE", worst3))

## FA4: negative correlation within a family (the help says to use Holm then)
set.seed(44)
p <- mvp(2e5, c(0, 0), matrix(c(1, -0.9, -0.9, 1), 2))
f4 <- sapply(c("hommel", "hochberg", "holm"), function(t) mean(rowSums(kern(p, family_spec(list(1:2), test = t), 1, matrix(0, 1, 1))) > 0))
cat(sprintf("      one family {1, 2}, rho = -0.9: FWER hommel %.4f  hochberg %.4f  holm %.4f\n", f4[1], f4[2], f4[3]))
note("FA4", f4[["holm"]] <= 0.025 + 3 * sqrt(0.025 * 0.975 / 2e5), "Holm keeps the level under negative dependence (Hommel and Hochberg are not expected to)")

## FA5: missing p-values inside a family
p <- rbind(c(0.001, NA, 0.002, 0.5), c(NA, NA, 0.001, 0.001), c(0.001, 0.001, 0.001, 0.001))
fs <- family_spec(list(1:2, 3:4)); w <- c(.5, .5); G <- matrix(c(0, 1, 1, 0), 2)
r5 <- tryCatch({ x <- calc_power_pvals(p, w, G, families = fs); paste("accepted; local power", paste(round(x$local_power, 3), collapse = " ")) }, error = function(e) paste("error:", conditionMessage(e)))
cat("      NA inside a family:", r5, "\n")
adj <- multigrain:::.prepare_pvals(p, fs)
cat("      adjusted p-values of row 1:", format(adj[1, ]), " | p.adjust on family 1:", format(p.adjust(p[1, 1:2], "hommel")), "\n")
note("FA5", grepl("^error", r5), "a missing p-value in a family is refused with a message (calc_power_pvals() accepts NA without families: entry B3_power)")

## FA6: invalid family specifications
bad <- list(
    "duplicate hypothesis"  = quote(family_spec(list(1, 1:2))),
    "missing hypothesis 2"  = quote(family_spec(list(1, 3))),
    "index 0"               = quote(family_spec(list(0:1, 2))),
    "NA index"              = quote(family_spec(list(c(1, NA), 2))),
    "index 1.5"             = quote(family_spec(list(1.5, 2))),
    "empty family"          = quote(family_spec(list(1:2, integer(0)))),
    "character indices"     = quote(family_spec(list("1", "2"))),
    "not a list"            = quote(family_spec(1:3)),
    "duplicate names"       = quote(family_spec(list(a = 1, a = 2))),
    "test 'Holm'"           = quote(family_spec(list(1, 2), test = "Holm")),
    "two tests, 3 families" = quote(family_spec(list(1, 2, 3), test = c("holm", "hommel"))),
    "no families"           = quote(family_spec(list()))
)
for (nm in names(bad)) {
    msg <- tryCatch({ eval(bad[[nm]]); "ACCEPTED" }, error = function(e) gsub("\n", " ", conditionMessage(e)))
    cat(sprintf("      %-22s -> %s\n", nm, substr(msg, 1, 120)))
}
acc <- names(bad)[vapply(bad, function(b) tryCatch({ eval(b); TRUE }, error = function(e) FALSE), NA)]
note("FA6", length(acc) == 0, paste("invalid specifications refused; accepted:", if (length(acc)) paste(acc, collapse = ", ") else "none"))

## FA7: the specification against the p-values and the graph
p <- mvp(500, rep(2, 5), exch(5, 0.3))
fs <- family_spec(list(1, 2:4, 5))
g3 <- list(w = rep(1 / 3, 3), G = { G <- matrix(.5, 3, 3); diag(G) <- 0; G })
chk <- list(
    "graph with 5 nodes (one per hypothesis)" = quote(calc_power_pvals(p, rep(.2, 5), { G <- matrix(.25, 5, 5); diag(G) <- 0; G }, families = fs)),
    "families for 6 hypotheses, 5 p-values"   = quote(calc_power_pvals(p, g3$w, g3$G, families = family_spec(list(1, 2:4, 5:6)))),
    "families as a plain list"                = quote(calc_power_pvals(p, g3$w, g3$G, families = list(1, 2:4, 5))),
    "sum_to_one_constraint = FALSE, row sum 2" = quote(calc_power_pvals(p, g3$w, rbind(c(0, 1, 1), c(.5, 0, .5), c(.5, .5, 0)), families = fs, sum_to_one_constraint = FALSE))
)
for (nm in names(chk)) {
    msg <- tryCatch({ x <- eval(chk[[nm]]); paste("ACCEPTED; disjunctive power", round(x$disj_power, 3)) }, error = function(e) gsub("\n", " ", conditionMessage(e)))
    cat(sprintf("      %-42s -> %s\n", nm, substr(msg, 1, 110)))
}
# A4 on the families path, with the catalogue's example: H1 false, H2 and H3 true nulls
set.seed(1)
p0 <- simulate_pvalues(c(0.9999, 0.025, 0.025), nsim = 2e5); fs3 <- family_spec(list(1, 2, 3))
f7 <- tryCatch(calc_power_pvals(p0, c(1, 0, 0), rbind(c(0, 1, 1), c(0, 0, 0), c(0, 0, 0)), families = fs3, sum_to_one_constraint = FALSE,
               custom_power = list(any_null = trial_success(r2 || r3, verbose = "silent")))$any_null, error = function(e) NA)
cat(sprintf("      A4 with families: P(reject a true null) with row 1 summing to 2: %s\n", format(f7, digits = 4)))
note("FA7", isTRUE(f7 <= 0.025 + 3 * sqrt(0.025 * 0.975 / 2e5)) || is.na(f7), "entry A4 does not carry over to the families path (a row sum of 2 is refused, or the level holds)")

## FA8: output fields and names
x <- calc_power_pvals(p, g3$w, g3$G, families = fs, custom_power = list(family_power = trial_success(r1 + r2 + r3 + r4 + r5, verbose = "silent")))
cat("      fields:", paste(names(x), collapse = ", "), "\n")
own <- calc_power_pvals(p, g3$w, g3$G, families = fs, custom_power = list(mine = trial_success(r1 + r2 + r3 + r4 + r5, verbose = "silent")))$mine
cat("      entries named family_power:", sum(names(x) == "family_power"), "| x$family_power:", paste(format(unlist(x$family_power), digits = 3), collapse = " "), "| the user's measure on its own:", format(own, digits = 4), "\n")
note("FA8", sum(names(x) == "family_power") == 1 && isTRUE(all.equal(unname(unlist(x$family_power)), own)), "a custom_power entry named family_power is returned under that name (cf. C20)")

## FA9: optimisation with families, end to end
set.seed(99)
P <- simulate_pvalues(c(0.9, 0.8, 0.8, 0.7, 0.6), corr_matrix = exch(5, 0.4), nsim = 5000)
gain <- trial_success(2 * r1 + (r2 && r3 && r4) + 0.5 * r5, verbose = "silent")
fit <- graph_optimise(P, graph_constraint_free(3), gain, families = fs, verbose = "silent")
re <- calc_power_pvals(P, fit$hyp_weight, fit$trans_matrix, families = fs, custom_power = list(g = gain))
pr <- tryCatch(paste(capture.output(print(fit)), collapse = "\n"), error = function(e) paste("print error:", conditionMessage(e)))
pl <- tryCatch({ grDevices::pdf(NULL); print(plot(fit)); grDevices::dev.off(); "ok" }, error = function(e) conditionMessage(e))
cat("      optimised weights:", round(fit$hyp_weight, 3), "| gain", round(fit$power$trial_success, 4), "| recomputed", round(re$g, 4), "\n")
cat("      plot():", pl, "\n")
note("FA9", isTRUE(all.equal(fit$power$trial_success, re$g)) && pl == "ok" && !grepl("^print error", pr), "graph_optimise() with families: reported gain equals calc_power_pvals(); print() and plot() work")
cat(pr, "\n")

## FA10: a large family
set.seed(1010)
p <- mvp(2e4, rep(1, 40), exch(40, 0.3))
fs40 <- family_spec(list(1:30, 31:40))
t40 <- system.time(x40 <- calc_power_pvals(p, c(.5, .5), matrix(c(0, 1, 1, 0), 2), families = fs40))[["elapsed"]]
note("FA10", is.finite(x40$disj_power), sprintf("families of 30 and 10 hypotheses, 20,000 trials: %.2f s", t40))

cat(sprintf("\n%d of %d checks passed\n", sum(unlist(res)), length(res)))
