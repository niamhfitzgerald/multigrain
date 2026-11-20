# fmt: skip file
# Independent reference for the group sequential graphical procedure (Maurer and Bretz 2013), written from the
# papers and the help pages, not from the package's code. Boundaries come straight from gsDesign::gsBound1() at the
# level a hypothesis holds; no repeated p-values, no interpolation. Shared by the D-scripts.
suppressMessages({ library(data.table); library(mvtnorm) })

# Bretz et al. (2009) graph update after removing hypothesis k
bretz_remove <- function(w, G, k) {
    m <- length(w); w2 <- w + w[k] * G[k, ]; w2[k] <- 0
    G2 <- matrix(0, m, m)
    for (i in seq_len(m)) for (j in seq_len(m)) if (i != j && i != k && j != k) {
        d <- 1 - G[i, k] * G[k, i]
        G2[i, j] <- if (d > 0) (G[i, j] + G[i, k] * G[k, j]) / d else 0
    }
    list(w = w2, G = G2)
}
# local weights for every set of rejected hypotheses (bit mask), removed in index order
all_weights <- function(w, G) {
    m <- length(w); out <- vector("list", 2^m)
    for (R in 0:(2^m - 1)) {
        st <- list(w = w, G = G)
        for (k in which(bitwAnd(R, 2^(0:(m - 1))) > 0)) st <- bretz_remove(st$w, st$G, k)
        out[[R + 1]] <- st$w
    }
    out
}
# nominal p-value boundaries of one hypothesis at level L over its analyses with distinct information t
boundary <- function(sf, L, t) {
    if (L <= 0) return(rep(-Inf, length(t)))
    if (length(t) == 1 && t[1] >= 1) return(L)
    cum <- pmin(sf(L, t), L); cum[length(cum)] <- if (t[length(t)] >= 1) L else cum[length(cum)]
    inc <- diff(c(0, cum))
    b <- gsDesign::gsBound1(theta = 0, I = t, a = rep(-20, length(t)), probhi = inc, tol = 1e-10)$b
    pnorm(-b)
}
# per hypothesis: analyses with data up to maturity
schedule <- function(tf) {                     # tf: one row of the m x K info-fraction matrix
    D <- which(!is.na(tf)); kmat <- D[which(tf[D] >= 1)[1]]; if (is.na(kmat)) kmat <- max(D)
    list(D = D[D <= kmat], kmat = kmat, t = tf[D[D <= kmat]])
}
# simulate raw p-values under the canonical joint normal model, with mvtnorm (independent of simulate_pvalues_gsd)
sim_raw <- function(nsim, delta, rho, info) {
    m <- nrow(info); K <- ncol(info)
    sc <- lapply(seq_len(m), function(i) schedule(info[i, ]))
    idx <- rbindlist(lapply(seq_len(m), function(i) data.table(i = i, k = sc[[i]]$D, t = sc[[i]]$t)))
    n <- nrow(idx); S <- matrix(0, n, n)
    for (a in seq_len(n)) for (b in seq_len(n)) {
        r <- if (idx$i[a] == idx$i[b]) 1 else rho[idx$i[a], idx$i[b]]
        S[a, b] <- r * sqrt(min(idx$t[a], idx$t[b]) / max(idx$t[a], idx$t[b]))
    }
    Z <- rmvnorm(nsim, delta[idx$i] * sqrt(idx$t), S)
    P <- array(NA_real_, c(nsim, m, K))
    for (a in seq_len(n)) P[, idx$i[a], idx$k[a]] <- pnorm(Z[, a], lower.tail = FALSE)
    for (i in seq_len(m)) if (sc[[i]]$kmat < K) for (k in (sc[[i]]$kmat + 1):K) P[, i, k] <- P[, i, sc[[i]]$kmat]
    P
}
# the procedure itself, trial by trial. rule: NULL or function(rejected logical vector) -> TRUE to stop.
# Returns decision times (0 = never) and, per trial, the smallest relative distance |p - c| / c met in any decision.
ref_gsd <- function(P, info, sfs, alpha, w, G, look_back, rule = NULL) {
    nsim <- dim(P)[1]; m <- dim(P)[2]; K <- dim(P)[3]
    sc <- lapply(seq_len(m), function(i) schedule(info[i, ]))
    W <- all_weights(w, G)
    cache <- new.env()
    bnd <- function(i, R) {                     # boundaries of hypothesis i when the set R is rejected
        key <- paste(i, R); if (!is.null(cache[[key]])) return(cache[[key]])
        v <- boundary(sfs[[i]], alpha * W[[R + 1]][i], sc[[i]]$t); cache[[key]] <- v; v
    }
    Tm <- matrix(0L, nsim, m); near <- rep(Inf, nsim)
    for (s in seq_len(nsim)) {
        R <- 0; rej <- rep(FALSE, m)
        for (k in seq_len(K)) {
            repeat {
                new <- integer(0)
                for (i in which(!rej)) {
                    D <- sc[[i]]$D; kk <- min(k, sc[[i]]$kmat)
                    pos <- which(D <= kk); if (!length(pos)) next
                    if (!look_back[i]) pos <- if (D[max(pos)] == kk) max(pos) else integer(0)
                    if (!length(pos)) next
                    cv <- bnd(i, R)[pos]; pv <- P[s, i, D[pos]]
                    near[s] <- min(near[s], abs(pv - cv) / cv, na.rm = TRUE)
                    if (any(pv <= cv)) new <- c(new, i)
                }
                if (!length(new)) break
                rej[new] <- TRUE; Tm[s, new] <- k; R <- sum(2^(which(rej) - 1))
            }
            if (all(rej)) break
            if (k < K && !is.null(rule) && isTRUE(rule(rej))) break
        }
    }
    list(times = Tm, near = near)
}
# decision times from the package, trial by trial, through a plain-function custom_power measure
pkg_times <- function(pv, w, G, rule = NULL, sum1 = TRUE) {
    env <- new.env(); env$n <- 0L; env$Tm <- matrix(NA_integer_, pv$nsim, pv$m)
    rec <- function(t) { env$n <- env$n + 1L; env$Tm[env$n, ] <- as.integer(t); 0 }
    out <- multigrain::calc_power_pvals_gsd(pv, hyp_weight = w, trans_matrix = G, custom_power = list(rec = rec),
                                            stopping_rule = rule, sum_to_one_constraint = sum1)
    list(times = env$Tm, n = env$n, out = out)
}
