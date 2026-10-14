#' Build a bank of repeated p-values over candidate spending functions
#'
#' `spending_bank_gsd()` transforms one array of raw group sequential p-values
#' once for each candidate spending function and keeps the results together,
#' so that [graph_optimise_gsd()] can choose the spending function alongside
#' the graph. Each candidate is passed to [transform_pvalues_gsd()] unchanged,
#' so a candidate may be a single function (applied to every hypothesis) or a
#' list of `m` functions.
#'
#' The usual case is a family indexed by one parameter, such as the
#' Hwang-Shih-DeCani family over a grid of `gamma`. The optimiser then picks
#' one grid value shared by all hypotheses, or one per hypothesis (see
#' `spending_shared` in [graph_optimise_gsd()]). The search over the bank is
#' discrete: nothing between two grid values is tried, so choose a grid that is
#' fine enough for the decision at hand.
#'
#' @inheritParams transform_pvalues_gsd
#' @param spending A named list of candidate spending functions. Each element
#'   is what [transform_pvalues_gsd()] accepts as its `spending` argument. The
#'   names label the candidates in the optimiser's output; unnamed candidates
#'   are labelled `cand1`, `cand2`, and so on.
#'
#' @returns A `multigrain_pvals_gsd_bank` object made up of:
#'   * `bank`: a list of `multigrain_pvals_gsd` objects, one per candidate,
#'     all built from the same raw p-values;
#'   * `labels`: the candidate names;
#'   * `nsim`, `m`, `K`, `alpha`: as for the members of the bank.
#'
#' @export
#' @examples
#' set.seed(1)
#' raw <- array(stats::runif(200 * 2 * 2), dim = c(200L, 2L, 2L))
#' hsd <- function(gamma) {
#'     force(gamma)
#'     function(alpha, t) gsDesign::sfHSD(alpha, t, gamma)
#' }
#' bank <- spending_bank_gsd(
#'     raw,
#'     info_frac = c(0.5, 1),
#'     spending = list(obf_like = hsd(-4), mid = hsd(-1), pocock_like = hsd(1)),
#'     grid_size = 128L
#' )
#' bank
spending_bank_gsd <- function(
    pvals,
    ...,
    info_frac = NULL,
    spending, # nolint: function_argument_linter. required, named after `...`
    alpha = 0.025,
    look_back = FALSE,
    grid_size = 1024L
) {
    rlang::check_dots_empty()
    rlang::check_required(spending)

    if (!is.list(spending) || length(spending) < 1L) {
        cli::cli_abort(
            "{.arg spending} must be a list of at least one candidate \\
            spending function."
        )
    }

    labels <- names(spending)
    if (is.null(labels)) {
        labels <- rep("", length(spending))
    }
    blank <- !nzchar(labels)
    labels[blank] <- paste0("cand", which(blank))
    if (anyDuplicated(labels)) {
        cli::cli_abort("The candidate names in {.arg spending} must be unique.")
    }

    members <- lapply(seq_along(spending), function(j) {
        transform_pvalues_gsd(
            pvals,
            info_frac = info_frac,
            spending = spending[[j]],
            alpha = alpha,
            look_back = look_back,
            grid_size = grid_size
        )
    })

    first <- members[[1L]]

    structure(
        list(
            bank = members,
            labels = labels,
            nsim = first$nsim,
            m = first$m,
            K = first$K,
            alpha = first$alpha
        ),
        class = "multigrain_pvals_gsd_bank"
    )
}

is_pvals_gsd_bank <- function(x) {
    inherits(x, "multigrain_pvals_gsd_bank")
}

check_pvals_gsd_bank <- function(
    pvals,
    arg = rlang::caller_arg(pvals),
    call = rlang::caller_env()
) {
    if (!missing(pvals) && is_pvals_gsd_bank(pvals)) {
        return(invisible(NULL))
    }
    rlang::stop_input_type(
        pvals,
        "a multigrain_pvals_gsd_bank object (see spending_bank_gsd())",
        arg = arg,
        call = call
    )
}

#' @export
print.multigrain_pvals_gsd_bank <- function(x, ...) {
    cat(
        sprintf(
            "<multigrain_pvals_gsd_bank>\n%d candidate spending function(s): %s\n",
            length(x$bank),
            paste(x$labels, collapse = ", ")
        )
    )
    cat(
        sprintf(
            "%d simulation(s), %d hypothes(es), %d analys(es); alpha = %s\n",
            x$nsim,
            x$m,
            x$K,
            format(x$alpha)
        )
    )
    invisible(x)
}

# The bank as one array: simulations by (m * K) kernel columns by candidate.
# Column (k - 1) * m + i is hypothesis i at analysis k, as in
# `.gsd_kernel_matrix()`.
.gsd_bank_array <- function(bank, call = rlang::caller_env()) {
    mats <- lapply(bank$bank, .gsd_kernel_matrix, call = call)
    out <- array(
        unlist(mats, use.names = FALSE),
        dim = c(bank$nsim, bank$m * bank$K, length(mats))
    )
    out
}

# Subsample the bank's trials, keeping every candidate on the same rows.
.sample_pvals_gsd_bank <- function(bank, nsim) {
    idx <- sample.int(bank$nsim, size = nsim, replace = FALSE)
    bank$bank <- lapply(bank$bank, function(p) {
        p$pvals <- p$pvals[idx, , , drop = FALSE]
        p$nsim <- nsim
        p
    })
    bank$nsim <- nsim
    bank
}

# Map the spending genes (each in [0, 1]) to candidate indices, one per
# hypothesis. `n_cand` equal intervals; the upper end maps to the last one.
.gsd_spending_choice <- function(genes, n_cand, m) {
    idx <- pmin(floor(genes * n_cand) + 1L, n_cand)
    idx <- pmax(idx, 1L)
    if (length(idx) == 1L) {
        idx <- rep(idx, m)
    }
    as.integer(idx)
}

# Assemble a kernel matrix from the bank array for a per-hypothesis choice of
# candidate. Hypothesis i takes columns i, i + m, ..., i + (K - 1) m from
# candidate choice[i].
.gsd_assemble_kernel <- function(bank_array, choice, m, K) { # nolint: object_name_linter.
    out <- bank_array[, , choice[[1L]], drop = TRUE]
    dim(out) <- c(dim(bank_array)[[1L]], m * K)
    if (length(unique(choice)) == 1L) {
        return(out)
    }
    for (i in seq_len(m)) {
        cols <- i + m * (seq_len(K) - 1L)
        out[, cols] <- bank_array[, cols, choice[[i]]]
    }
    out
}

# A `multigrain_pvals_gsd` object holding the chosen candidate for each
# hypothesis, so that the rest of the pipeline sees an ordinary object.
.gsd_assemble_pvals <- function(bank, choice) {
    first <- bank$bank[[choice[[1L]]]]
    out <- first
    for (i in seq_len(bank$m)) {
        member <- bank$bank[[choice[[i]]]]
        out$pvals[, i, ] <- member$pvals[, i, ]
        out$info_frac[i, ] <- member$info_frac[i, ]
        out$look_back[[i]] <- member$look_back[[i]]
        out$tables[[i]] <- member$tables[[i]]
    }
    out$spending <- bank$labels[choice]
    out
}
