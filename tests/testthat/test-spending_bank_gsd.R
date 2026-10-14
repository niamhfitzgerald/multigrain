# `spending_bank_gsd()` keeps one transform per candidate spending function;
# `graph_optimise_gsd()` then chooses the candidate (shared, or one per
# hypothesis) in the global stage alongside the graph.

bank_raw <- withr::with_seed(303, {
    simulate_pvalues_gsd(
        power_nominal = c(0.95, 0.85, 0.7),
        corr_matrix = diag(3),
        info_frac = c(0.5, 1),
        nsim = 2000
    )
})

hsd_fun <- function(gamma) {
    force(gamma)
    function(alpha, t) gsDesign::sfHSD(alpha, t, gamma)
}

bank_candidates <- list(
    obf_like = hsd_fun(-4),
    mid = hsd_fun(-1),
    pocock_like = hsd_fun(1)
)

bank <- spending_bank_gsd(
    bank_raw,
    spending = bank_candidates,
    grid_size = 128L
)

bank_control <- multigrain_control() |>
    control_global(maxiter = 30, run = 10, popSize = 40) |>
    control_local(maxeval = 200) |>
    control_nsim_global(1000)

test_that("the bank holds one transform per candidate, on the same trials", {
    expect_s3_class(bank, "multigrain_pvals_gsd_bank")
    expect_length(bank$bank, 3L)
    expect_identical(bank$labels, names(bank_candidates))
    expect_identical(bank$nsim, 2000L)
    expect_identical(bank$m, 3L)
    expect_identical(bank$K, 2L)

    direct <- transform_pvalues_gsd(
        bank_raw,
        spending = hsd_fun(-1),
        grid_size = 128L
    )
    expect_equal(bank$bank[[2L]]$pvals, direct$pvals)
})

test_that("unnamed candidates are labelled and duplicates rejected", {
    unnamed <- spending_bank_gsd(
        bank_raw,
        spending = list(hsd_fun(-4), hsd_fun(1)),
        grid_size = 64L
    )
    expect_identical(unnamed$labels, c("cand1", "cand2"))

    expect_error(
        spending_bank_gsd(
            bank_raw,
            spending = list(a = hsd_fun(-4), a = hsd_fun(1)),
            grid_size = 64L
        ),
        "unique"
    )
    expect_error(
        spending_bank_gsd(bank_raw, spending = list(), grid_size = 64L),
        "at least one"
    )
})

test_that("assembling a per-hypothesis choice matches a direct transform", {
    choice <- c(3L, 1L, 2L)
    assembled <- multigrain:::.gsd_assemble_pvals(bank, choice)
    direct <- transform_pvalues_gsd(
        bank_raw,
        spending = list(hsd_fun(1), hsd_fun(-4), hsd_fun(-1)),
        grid_size = 128L
    )
    expect_equal(assembled$pvals, direct$pvals)
    expect_identical(assembled$spending, bank$labels[choice])

    arr <- multigrain:::.gsd_bank_array(bank)
    expect_identical(dim(arr), c(2000L, 6L, 3L))
    kernel <- multigrain:::.gsd_assemble_kernel(arr, choice, 3L, 2L)
    expect_equal(kernel, multigrain:::.gsd_kernel_matrix(direct))
})

test_that("spending genes map to candidates by equal intervals", {
    expect_identical(
        multigrain:::.gsd_spending_choice(c(0, 0.33, 0.34, 0.66, 0.67, 1), 3L, 6L),
        c(1L, 1L, 2L, 2L, 3L, 3L)
    )
    # a shared gene is repeated for every hypothesis
    expect_identical(multigrain:::.gsd_spending_choice(0.5, 3L, 4L), rep(2L, 4L))
})

test_that("a gain that rewards early rejection picks the Pocock-like candidate", {
    early <- trial_success_gsd(
        2 * (t1 == 1) + 2 * (t2 == 1) + 2 * (t3 == 1) + r1 + r2 + r3,
        K = 2,
        verbose = "silent"
    )
    res <- withr::with_seed(404, {
        graph_optimise_gsd(
            bank,
            graph_constraint(hyp_constraint = c(1, 0, 0)),
            early,
            control = bank_control,
            verbose = "silent"
        )
    })
    expect_s3_class(res, "multigrain_graph_optimal")
    expect_identical(unname(res$spending$label), rep("pocock_like", 3L))
    expect_true(res$spending$shared)
    expect_identical(res$spending$candidates, bank$labels)
    expect_s3_class(res$pvals_chosen, "multigrain_pvals_gsd")

    # the reported power is evaluated on the chosen p-values
    recomputed <- calc_power_pvals_gsd(
        res$pvals_chosen,
        hyp_weight = res$hyp_weight,
        trans_matrix = res$trans_matrix,
        custom_power = list(g = early)
    )$g
    expect_equal(res$power$trial_success, recomputed)
})

test_that("a gain that rewards only final rejections picks the OBF-like candidate", {
    late <- trial_success_gsd(r1 + r2 + r3, K = 2, verbose = "silent")
    res <- withr::with_seed(404, {
        graph_optimise_gsd(
            bank,
            graph_constraint(hyp_constraint = c(1, 0, 0)),
            late,
            control = bank_control,
            verbose = "silent"
        )
    })
    expect_identical(unname(res$spending$label), rep("obf_like", 3L))
})

test_that("a per-hypothesis choice can differ between hypotheses", {
    mixed <- trial_success_gsd(
        3 * (t1 == 1) + r1 + r2 + r3,
        K = 2,
        verbose = "silent"
    )
    res <- withr::with_seed(404, {
        graph_optimise_gsd(
            bank,
            graph_constraint(hyp_constraint = c(1, 0, 0)),
            mixed,
            spending_shared = FALSE,
            control = bank_control,
            verbose = "silent"
        )
    })
    expect_false(res$spending$shared)
    expect_identical(unname(res$spending$label[[1L]]), "pocock_like")
    expect_identical(unname(res$spending$label[2:3]), rep("obf_like", 2L))
})

test_that("a bank without the global search is refused", {
    gain <- trial_success_gsd(r1 + r2 + r3, K = 2, verbose = "silent")
    expect_error(
        graph_optimise_gsd(
            bank,
            graph_constraint(hyp_constraint = c(1, 0, 0)),
            gain,
            global_search = FALSE,
            verbose = "silent"
        ),
        "global search"
    )
})

test_that("a plain pvals object still optimises the graph alone", {
    gain <- trial_success_gsd(r1 + r2 + r3, K = 2, verbose = "silent")
    res <- withr::with_seed(404, {
        graph_optimise_gsd(
            bank$bank[[3L]],
            graph_constraint(hyp_constraint = c(1, 0, 0)),
            gain,
            control = bank_control,
            verbose = "silent"
        )
    })
    expect_null(res$spending)
    expect_null(res$pvals_chosen)
})
