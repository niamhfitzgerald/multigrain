# DS3 fix: in create_obj_func_gsd(), in place of the closure's last line, power_criterion(res$time)
# (R/objective_function_gsd.R:106 at 31ada01); in create_obj_func() the same with rej_matrix (R/objective_function.R:87)
# fmt: skip file
gain <- power_criterion(res$time)
if (!is.finite(gain)) {
    cli::cli_abort(c(
        "The trial success function gives {gain} for this graph, not a finite number.",
        i = "A division by a decision time or a rejection indicator that can be 0, \\
            such as {.code r1 / t1}, gives 0/0 in the trials where that hypothesis \\
            is not rejected."
    ), call = NULL)
}
gain
