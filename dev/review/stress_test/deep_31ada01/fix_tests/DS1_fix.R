# DS1 fix: in transform_pvalues_gsd(), in place of R/transform_pvalues_gsd.R:137-139 at 31ada01
# fmt: skip file
attached <- attr(pvals, "info_frac")
if (is.null(info_frac)) {
    info_frac <- attached
} else if (!is.null(attached)) {
    given_n <- .gsd_info_frac(info_frac, m = m, n_look = n_look)
    attached_n <- .gsd_info_frac(attached, m = m, n_look = n_look)
    if (!identical(is.na(given_n), is.na(attached_n)) ||
        !isTRUE(all.equal(given_n, attached_n, check.attributes = FALSE))) {
        cli::cli_abort(c(
            "{.arg info_frac} differs from the {.field info_frac} attribute of {.arg pvals}.",
            x = "The p-values were simulated at different information fractions, \\
                so the boundaries would not match their correlation.",
            i = "Leave {.arg info_frac} out to use the attribute, or remove the \\
                attribute if the p-values come from elsewhere."
        ))
    }
}
