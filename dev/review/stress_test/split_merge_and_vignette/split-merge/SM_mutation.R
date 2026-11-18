# fmt: skip file
# Properties of the split-merge mutation (R/mutation_helpers.R on split-merge, ff9d907), checked on 20,000 calls
# across 6 graph constraints: every child decodes to a valid graph, keeps every fixed entry, differs from its parent,
# and leaves latent positions outside the mutable groups alone.
# Run: R_LIBS=<split-merge build> Rscript SM_mutation.R
suppressMessages({ library(multigrain); library(data.table) })
ns <- asNamespace("multigrain")
setClass("fake_ga", representation(population = "matrix"))
encode <- function(w, G, hc, tc) {               # latent vector: free entries less the last of each group
    x <- numeric(0); fw <- which(is.na(hc)); if (length(fw) >= 2) x <- c(x, w[fw[-length(fw)]])
    for (i in seq_len(nrow(tc))) { f <- which(is.na(tc[i, ])); if (length(f) >= 2) x <- c(x, G[i, f[-length(f)]]) }
    x
}
decode <- function(x, hc, tc) {
    s <- ns$split_theta(x, hc)
    list(w = ns$recover_full_weights(s$w_pars, hc), G = ns$recover_full_trans_matrix(s$g_pars, tc))
}
random_graph <- function(hc, tc) {               # a random graph that meets the constraint
    w <- hc; f <- which(is.na(hc)); w[f] <- (1 - sum(hc, na.rm = TRUE)) * { v <- rexp(length(f)); v / sum(v) }
    G <- tc
    for (i in seq_len(nrow(tc))) { f <- which(is.na(tc[i, ])); if (length(f)) G[i, f] <- (1 - sum(tc[i, ], na.rm = TRUE)) * { v <- rexp(length(f)) * (runif(length(f)) > 0.3); if (sum(v) == 0) v[1] <- 1; v / sum(v) } }
    list(w = w, G = G)
}
free3 <- graph_constraint_free(3); free6 <- graph_constraint_free(6)
cons <- list(
    "free, m = 3" = list(hc = free3$hyp_constraint, tc = free3$trans_constraint),
    "free, m = 6" = list(hc = free6$hyp_constraint, tc = free6$trans_constraint),
    "weights fixed" = list(hc = c(0.5, 0.3, 0.2), tc = free3$trans_constraint),
    "one weight fixed at 0.4" = list(hc = c(0.4, NA, NA, NA), tc = graph_constraint_free(4)$trans_constraint),
    "a row fully fixed, a row with one free entry" = list(hc = c(NA, NA, NA, NA), tc = rbind(c(0, 0.5, 0.5, 0), c(0, 0, NA, 0.6), c(NA, NA, 0, NA), c(NA, NA, NA, 0))),
    "fixed edges of 0.001 and 1e-4" = list(hc = c(NA, NA, NA), tc = rbind(c(0, 0.001, NA), c(NA, 0, 1e-4), c(NA, NA, 0)))
)
set.seed(4242)
rows <- list(); first_bad <- NULL
for (nm in names(cons)) {
    hc <- cons[[nm]]$hc; tc <- cons[[nm]]$tc
    groups <- ns$.sm_groups(hc, tc); in_group <- sort(unlist(lapply(groups, `[[`, "latent")))
    mut <- ns$.make_split_merge_mutation(hc, tc)
    # parents: random valid graphs; each group's free entries are shrunk by 1e-12 so that rounding cannot leave the
    # derived entry below 0 (a parent that decodes to an invalid graph would make its child invalid too)
    pop <- t(replicate(50, { g <- random_graph(hc, tc); encode(g$w, g$G, hc, tc) * (1 - 1e-12) }))
    if (length(encode(hc, tc, hc, tc)) <= 1) pop <- matrix(pop, ncol = 1)
    obj <- new("fake_ga", population = pop)
    parents_valid <- sum(apply(pop, 1, function(x) { d <- decode(x, hc, tc); isTRUE(tryCatch(is_graph_valid(d$w, d$G), error = function(e) FALSE)) }))
    n <- 0; bad_valid <- 0; bad_fixed <- 0; same <- 0; bad_outside <- 0; bad_range <- 0
    for (r in 1:(20000 / length(cons))) {
        parent <- sample.int(nrow(pop), 1); x0 <- pop[parent, ]; x1 <- mut(obj, parent)
        d <- decode(x1, hc, tc); n <- n + 1
        if (any(!is.finite(x1)) || any(x1 < 0 | x1 > 1)) bad_range <- bad_range + 1
        wmsg <- character(0)
        ok <- isTRUE(withCallingHandlers(tryCatch(is_graph_valid(d$w, d$G), error = function(e) FALSE),
                                         warning = function(w) { wmsg <<- c(wmsg, conditionMessage(w)); invokeRestart("muffleWarning") }))
        if (!ok) { bad_valid <- bad_valid + 1; if (is.null(first_bad)) first_bad <- list(constraint = nm, parent = x0, child = x1, w = d$w, G = d$G, warning = wmsg) }
        if (any(d$w[!is.na(hc)] != hc[!is.na(hc)]) || any(d$G[!is.na(tc)] != tc[!is.na(tc)])) bad_fixed <- bad_fixed + 1
        if (length(groups) && identical(x0, x1)) same <- same + 1
        if (any(x1[setdiff(seq_along(x1), in_group)] != x0[setdiff(seq_along(x0), in_group)])) bad_outside <- bad_outside + 1
    }
    rows[[nm]] <- data.table(constraint = nm, groups = length(groups), valid_parents = parents_valid, calls = n, out_of_range = bad_range, invalid_graph = bad_valid,
                             fixed_changed = bad_fixed, child_equals_parent = same, outside_changed = bad_outside)
}
print(rbindlist(rows), row.names = FALSE)
if (!is.null(first_bad)) {
    saveRDS(first_bad, "SM_mutation_first_invalid.rds")
    cat("\nfirst invalid child (", first_bad$constraint, "):\n", sep = "")
    cat("  is_graph_valid() warning:", unique(gsub("\\s+", " ", first_bad$warning)), "\n")
    cat("  weights:", format(first_bad$w, digits = 17), "\n  sum of weights - 1:", sum(first_bad$w) - 1, "\n")
    cat("  row sums of G - 1:", format(rowSums(first_bad$G) - 1, digits = 3), "\n")
}
cat("EXPECTED: 50 valid parents and 0 in every count column after calls\n")
