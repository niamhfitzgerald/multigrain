# fmt: skip file
# D7: extreme designs. Each runs in its own R process with a time limit; records success, time, peak memory where
# available, and a sanity value (familywise error under the global null on 20,000 trials where it applies).
# Usage: R_LIBS=<build> Rscript D7_extremes.R <out.rds>
args <- commandArgs(TRUE)
suppressMessages(library(data.table))
designs <- list(
  "K = 6, equal looks"             = quote(list(m = 2, info = (1:6) / 6, sf = "OF", alpha = 0.025)),
  "K = 10, equal looks"            = quote(list(m = 2, info = (1:10) / 10, sf = "OF", alpha = 0.025)),
  "K = 10, Pocock"                 = quote(list(m = 3, info = (1:10) / 10, sf = "Pocock", alpha = 0.025)),
  "interim at 1%, OF"              = quote(list(m = 2, info = c(0.01, 1), sf = "OF", alpha = 0.025)),
  "interim at 1%, Pocock"          = quote(list(m = 2, info = c(0.01, 1), sf = "Pocock", alpha = 0.025)),
  "interim at 0.1%, Pocock"        = quote(list(m = 2, info = c(0.001, 1), sf = "Pocock", alpha = 0.025)),
  "alpha 1e-4"                     = quote(list(m = 3, info = c(0.5, 1), sf = "OF", alpha = 1e-4)),
  "alpha 1e-6"                     = quote(list(m = 2, info = c(0.5, 1), sf = "OF", alpha = 1e-6)),
  "alpha 0.2"                      = quote(list(m = 3, info = c(0.5, 1), sf = "Pocock", alpha = 0.2)),
  "alpha 0.5"                      = quote(list(m = 2, info = c(0.5, 1), sf = "Pocock", alpha = 0.5)),
  "m = 8, K = 3"                   = quote(list(m = 8, info = c(0.4, 0.7, 1), sf = "OF", alpha = 0.025)),
  "m = 12, K = 2"                  = quote(list(m = 12, info = c(0.5, 1), sf = "OF", alpha = 0.025)),
  "m = 16, K = 2, rule"            = quote(list(m = 16, info = c(0.5, 1), sf = "OF", alpha = 0.025, rule = TRUE)),
  "m = 17, K = 2, rule"            = quote(list(m = 17, info = c(0.5, 1), sf = "OF", alpha = 0.025, rule = TRUE)),
  "every hypothesis late"          = quote(list(m = 3, info = rbind(c(NA, 0.5, 1), c(NA, 0.5, 1), c(NA, NA, 1)), sf = "OF", alpha = 0.025)),
  "different schedules"            = quote(list(m = 3, info = rbind(c(0.2, 0.4, 1, 1), c(NA, 0.3, 0.9, 1), c(1, 1, 1, 1)), sf = "Pocock", alpha = 0.025)),
  "grid_size 4096"                 = quote(list(m = 2, info = c(0.3, 0.6, 1), sf = "OF", alpha = 0.025, grid = 4096L)),
  "grid_size 64"                   = quote(list(m = 2, info = c(0.3, 0.6, 1), sf = "OF", alpha = 0.025, grid = 64L)),
  "nsim 1e6, m 4, K 3"             = quote(list(m = 4, info = c(0.4, 0.7, 1), sf = "OF", alpha = 0.025, nsim = 1e6, fwer = FALSE)),
  "joint search, m 5, K 3, rule"   = quote(list(m = 5, info = c(0.4, 0.7, 1), sf = "joint", alpha = 0.025, nsim = 3000, rule = TRUE, optimise = TRUE)),
  "joint search, m 3, lattice 97"  = quote(list(m = 3, info = c(0.3, 0.6, 1), sf = "joint97", alpha = 0.025, nsim = 3000, optimise = TRUE))
)
run_one <- function(spec) {
    suppressMessages(library(multigrain)); options(multigrain.verbosity = "silent")
    s <- eval(spec); m <- s$m; nsim <- if (is.null(s$nsim)) 20000 else s$nsim; grid <- if (is.null(s$grid)) 1024L else s$grid
    sf <- switch(s$sf, OF = function(a, t) gsDesign::sfLDOF(a, t)$spend, Pocock = function(a, t) gsDesign::sfLDPocock(a, t)$spend,
                 joint = sf_hsd_opt(bounds = c(-4, 1), step = 0.5), joint97 = sf_hsd_opt(bounds = c(-10, 2), step = 0.125))
    t0 <- proc.time()[["elapsed"]]
    set.seed(1)
    raw <- simulate_pvalues_gsd(rep(if (isTRUE(s$fwer == FALSE) || isTRUE(s$optimise)) 0.8 else s$alpha, m), alpha = s$alpha,
                                corr_matrix = { r <- matrix(0.3, m, m); diag(r) <- 1; r }, info_frac = s$info, nsim = nsim)
    pv <- transform_pvalues_gsd(raw, spending = sf, alpha = s$alpha, grid_size = grid)
    w <- rep(1 / m, m); G <- matrix(1 / (m - 1), m, m); diag(G) <- 0
    rule <- if (isTRUE(s$rule)) stopping_rule_gsd(r1) else NULL
    val <- if (isTRUE(s$optimise)) {
        g <- trial_success_gsd(!!rlang::parse_expr(paste0("r", seq_len(m), collapse = " + ")))
        set.seed(2); o <- graph_optimise_gsd(pv, graph_constraint_free(m), g, stopping_rule = rule, num_threads = 2)
        sprintf("gain %.4f at %s", o$power$trial_success, paste(unlist(o$spending_param), collapse = ","))
    } else {
        r <- calc_power_pvals_gsd(pv, w, G, stopping_rule = rule)
        if (isTRUE(s$fwer == FALSE)) sprintf("disjunctive power %.4f", r$disj_power) else sprintf("familywise error %.4f (alpha %g, SE %.2g)", r$disj_power, s$alpha, sqrt(s$alpha * (1 - s$alpha) / nsim))
    }
    list(value = val, seconds = round(proc.time()[["elapsed"]] - t0, 1))
}
rows <- list()
for (nm in names(designs)) {
    r <- tryCatch(callr::r(run_one, args = list(spec = designs[[nm]]), libpath = .libPaths(), timeout = 1200),
                  error = function(e) list(value = paste("ERROR:", substr(gsub("\\s+", " ", conditionMessage(e)), 1, 300)), seconds = NA))
    rows[[nm]] <- data.table(design = nm, result = r$value, seconds = r$seconds)
    cat(sprintf("%-32s %-8s %s\n", nm, r$seconds, r$value))
}
saveRDS(rbindlist(rows), args[1])
