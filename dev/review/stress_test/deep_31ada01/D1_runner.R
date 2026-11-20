# fmt: skip file
# Runs D1 cases from index <start>; appends one line per case to <out.tsv>; writes the index before each case
# to <progress> so that a crash can be attributed. Usage: Rscript D1_runner.R <dir> <start> <out.tsv> <progress>
a <- commandArgs(TRUE); dir <- a[1]; start <- as.integer(a[2])
source(file.path(dir, "D1_setup.R")); source(file.path(dir, "D1_cases.R"))
clean <- function(x) gsub("[\t\r\n]+", " ", paste(x, collapse = " "))
summ <- function(x) {
    if (inherits(x, "multigrain_pvals_gsd")) return(sprintf("pvals_gsd %s; range %s; NA %d", paste(dim(x$pvals), collapse = "x"),
        paste(signif(range(x$pvals, na.rm = TRUE), 3), collapse = " to "), sum(is.na(x$pvals))))
    if (is.array(x) && is.numeric(x)) return(sprintf("array %s; NA %d; range %s", paste(dim(x), collapse = "x"), sum(is.na(x)),
        if (all(is.na(x))) "all NA" else paste(signif(range(x, na.rm = TRUE), 3), collapse = " to ")))
    if (is.list(x) && !is.null(x$local_power)) return(paste("local_power", paste(signif(x$local_power, 3), collapse = " ")))
    if (is.function(x)) return(paste("function of class", paste(class(x), collapse = "/")))
    if (is.atomic(x) && length(x) <= 12) return(paste(class(x)[1], ":", paste(format(x, digits = 4), collapse = " ")))
    paste(class(x)[1], clean(utils::capture.output(utils::str(x, max.level = 1, give.attr = FALSE))[1:2]))
}
for (i in seq(start, length(cases))) {
    writeLines(as.character(i), a[4])
    warns <- character(0); t0 <- proc.time()[["elapsed"]]
    res <- withCallingHandlers(tryCatch(list(ok = TRUE, value = eval(cases[[i]], globalenv())),
                                        error = function(e) list(ok = FALSE, cls = class(e)[1], msg = conditionMessage(e),
                                                                 call = if (is.null(conditionCall(e))) "" else clean(deparse(conditionCall(e))[1]))),
                               warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") },
                               message = function(m) invokeRestart("muffleMessage"))
    el <- round(proc.time()[["elapsed"]] - t0, 2)
    line <- if (res$ok) c(names(cases)[i], "ok", "", clean(summ(res$value)), clean(warns), el)
            else c(names(cases)[i], "error", res$cls, clean(substr(paste(res$call, "::", res$msg), 1, 400)), clean(warns), el)
    cat(paste(line, collapse = "\t"), "\n", sep = "", file = a[3], append = TRUE)
}
writeLines("done", a[4])
