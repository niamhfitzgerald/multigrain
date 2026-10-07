# DOC9: a development vignette documents optimize_N(), which the package no longer has
# Run from the repository root: Rscript DOC9.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

v <- readLines("dev/vignettes/opt-sample-size.Rmd")
cat("lines of dev/vignettes/opt-sample-size.Rmd that mention optimize_N:",
    sum(grepl("optimize_N", v)), "\n")
cat("optimize_N or optimise_N in the package:",
    any(c("optimize_N", "optimise_N") %in% ls(asNamespace("multigrain"))), "\n")
cat("NEWS.md:", grep("optimise_N()`) has been removed", readLines("NEWS.md"), fixed = TRUE, value = TRUE), "\n")

cat("the vignette reads:", trimws(grep("readRDS", v, value = TRUE)),
    "; file present next to it:", file.exists("dev/vignettes/data/optN_result.rds"), "\n")
arts <- list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$", full.names = TRUE)
cat("published articles that use vignettes/articles/data/optN_result.rds:",
    sum(grepl("optN_result", unlist(lapply(arts, readLines)))), "\n")
x <- readRDS("vignettes/articles/data/optN_result.rds")
cat("class of that stored object:", class(x), "; lines printed by print():", length(capture.output(print(x))), "\n")
cat("EXPECTED: no vignette and no data file for a removed function, or a vignette that runs\n")
