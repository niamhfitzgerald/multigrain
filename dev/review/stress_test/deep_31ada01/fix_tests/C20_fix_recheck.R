# C20's fix of the type message, tried again in a session on 31ada01: put the object inside braces so that cli describes it.
# Usage, from this folder: Rscript C20_fix_recheck.R C20_recheck.R
# fmt: skip file
suppressMessages(library(multigrain))
ns <- asNamespace("multigrain")
patch <- function(fname) {
    f <- get(fname, ns); src <- deparse(f)
    src <- gsub("not {.obj_type_friendly item}", "not {.obj_type_friendly {item}}", src, fixed = TRUE)
    g <- eval(parse(text = src)); environment(g) <- ns; utils::assignInNamespace(fname, g, ns = "multigrain")
}
patch(".auto_name_custom_power"); patch(".auto_name_custom_power_gsd")
source(commandArgs(TRUE)[1])
