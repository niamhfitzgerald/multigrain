# fmt: skip file
# D5b: rerun of D5 part (A) inside the documented gain grammar (help line 17): `&&`/`||` take logical operands, no `!`,
# and a zero term 0 * r3 is added when an expression leaves out H3 (catalogue C21 refuses such a gain otherwise).
# D5: (A) random gain expressions compiled by trial_success_gsd() against plain R evaluation of the same expression on
# the same decision times; each compile runs in its own R process, so a crash is recorded, not fatal.
# (B) random stopping rules: package decision times against the reference (ref_lib.R) with the rule evaluated in R.
# Usage: R_LIBS=<build> Rscript D5b_gains.R <n_gains> <seed> <out.rds>
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "ref_lib.R"))
suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
set.seed(as.integer(args[2]))
m <- 3; K <- 3
info <- rbind(c(0.4, 0.7, 1), c(NA, 0.6, 1), c(0.5, 1, 1))
sfs <- list(function(a, t) gsDesign::sfLDOF(a, t)$spend, function(a, t) gsDesign::sfLDPocock(a, t)$spend, function(a, t) gsDesign::sfHSD(a, t, -2)$spend)
P <- sim_raw(3000, delta = c(2.8, 2.5, 2.2), rho = matrix(c(1, 0.4, 0.2, 0.4, 1, 0.3, 0.2, 0.3, 1), 3), info = info)
pv <- transform_pvalues_gsd(P, info_frac = info, spending = sfs, look_back = c(FALSE, TRUE, FALSE))
w <- c(0.5, 0.3, 0.2); G <- rbind(c(0, 0.6, 0.4), c(0.5, 0, 0.5), c(0.7, 0.3, 0))
pv_file <- tempfile(fileext = ".rds"); saveRDS(list(pv = pv, w = w, G = G), pv_file)
tabs <- list(d = c(1, 0.7, 0.4), e = c(2, 1, 0.5))

## (A) gains
gen_bool <- function(depth = 0) {
    i <- sample(m, 1); j <- sample(setdiff(1:m, i), 1)
    atoms <- list(as.name(paste0("r", i)), call("==", as.name(paste0("t", i)), sample(0:3, 1)),
                  call("<", as.name(paste0("t", i)), as.name(paste0("t", j))), call("<=", as.name(paste0("t", i)), sample(1:3, 1)))
    if (depth >= 2 || runif(1) < 0.5) return(atoms[[sample(length(atoms), 1)]])
    call(sample(c("&&", "||"), 1), call("(", gen_bool(depth + 1)), call("(", gen_bool(depth + 1)))
}
gen <- function(depth = 0) {
    i <- sample(m, 1)
    atoms <- list(as.name(paste0("r", i)), as.name(paste0("t", i)), call("d", as.name(paste0("t", i))), call("e", as.name(paste0("t", i))),
                  sample(c(0.5, 2, 3, 1.25), 1), call("(", gen_bool(1)))
    if (depth >= 3 || runif(1) < 0.3) return(atoms[[sample(length(atoms), 1)]])
    op <- sample(c("+", "-", "*", "/", "neg", "paren"), 1, prob = c(4, 2, 3, 1.2, 0.7, 0.8))
    a <- gen(depth + 1); b <- gen(depth + 1)
    switch(op, "/" = call("/", a, call("+", 1, as.name(paste0("t", i)))), neg = call("-", a), paren = call("(", a), call(op, a, b))
}
with_h3 <- function(ex) if (any(grepl("3$", all.names(ex)))) ex else call("+", ex, quote(0 * r3))
edge <- list(quote(r1 / 2), quote(t1 / 2), quote(t1 / t2), quote((r1 + r2) / 2), quote(-t1 * 2), quote(r1 - r2 * t3), quote(t1 == t2),
             quote(d(t1) / e(t2)), quote(r1 + r2 + r3 >= 2), quote((t1 > 0) + (t2 > 0)), quote(3 - t1), quote(r1 * (t1 <= 1) + 0.5 * r2),
             quote(t1 / t2 / t3), quote(r1 - r2 - r3), quote(2 * t1 - t2 * 3), quote(d(t1) * d(t2) * d(t3)), quote((r1 && r2) * e(t3)))
exprs <- lapply(c(edge, replicate(max(0, as.integer(args[1]) - length(edge)), gen(), simplify = FALSE)), with_h3)
r_eval <- function(ex, Tm) {                       # plain R, element-wise, on the decision times
    vec <- function(e) { if (is.call(e)) { if (identical(e[[1]], as.name("&&"))) e[[1]] <- as.name("&"); if (identical(e[[1]], as.name("||"))) e[[1]] <- as.name("|")
                            for (k in seq_along(e)[-1]) e[[k]] <- vec(e[[k]]) }; e }
    env <- list2env(c(setNames(lapply(1:m, function(i) Tm[, i] > 0), paste0("r", 1:m)), setNames(lapply(1:m, function(i) Tm[, i]), paste0("t", 1:m)),
                      list(d = function(x) c(0, tabs$d)[x + 1], e = function(x) c(0, tabs$e)[x + 1])))
    v <- eval(vec(ex), env); if (length(v) == 1) v <- rep(v, nrow(Tm)); mean(as.numeric(v))
}
rowsA <- list()
for (q in seq_along(exprs)) {
    ex <- exprs[[q]]
    out <- tryCatch(callr::r(function(ex, pv_file, tabs) {
        suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
        o <- readRDS(pv_file); env <- new.env(); env$n <- 0L; env$Tm <- matrix(NA_integer_, o$pv$nsim, o$pv$m)
        rec <- function(t) { env$n <- env$n + 1L; env$Tm[env$n, ] <- as.integer(t); 0 }
        g <- tryCatch(do.call(trial_success_gsd, c(list(ex), tabs)), error = function(e) e)
        if (inherits(g, "error")) return(list(status = "refused", msg = conditionMessage(g)))
        r <- tryCatch(calc_power_pvals_gsd(o$pv, o$w, o$G, custom_power = list(g = g, rec = rec)), error = function(e) e)
        if (inherits(r, "error")) return(list(status = "eval error", msg = conditionMessage(r)))
        list(status = "ok", value = r$g, Tm = env$Tm)
    }, args = list(ex = ex, pv_file = pv_file, tabs = tabs), libpath = .libPaths()),
        error = function(e) list(status = "crash", msg = conditionMessage(e)))
    ref <- if (out$status == "ok") tryCatch(r_eval(ex, out$Tm), error = function(e) NA_real_) else NA_real_
    rowsA[[q]] <- data.table(id = q, expr = paste(deparse(ex, width.cutoff = 500), collapse = ""), status = out$status,
                             pkg = if (out$status == "ok") out$value else NA_real_, r = ref,
                             msg = if (is.null(out$msg)) "" else substr(gsub("\\s+", " ", out$msg), 1, 200))
}
A <- rbindlist(rowsA)
A[, agree := status == "ok" & !is.na(r) & abs(pkg - r) <= 1e-12 * pmax(1, abs(r))]

saveRDS(A, args[3])
cat(sprintf("(A) gains: %d expressions; compiled and evaluated %d; refused %d; evaluation errors %d; crashes %d\n", nrow(A),
            sum(A$status == "ok"), sum(A$status == "refused"), sum(A$status == "eval error"), sum(A$status == "crash")))
cat(sprintf("    agree with R to 1e-12: %d of %d\n", sum(A$agree), sum(A$status == "ok")))
if (any(A$status == "ok" & !A$agree)) print(A[status == "ok" & !agree, .(id, expr, pkg = signif(pkg, 6), r = signif(r, 6))], row.names = FALSE)
if (any(A$status != "ok")) print(A[status != "ok", .(id, expr, status, msg = substr(msg, 1, 110))], row.names = FALSE)
