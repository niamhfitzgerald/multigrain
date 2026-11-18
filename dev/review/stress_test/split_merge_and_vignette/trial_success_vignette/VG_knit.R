# fmt: skip file
# Knit the trial success article of trial_success_vignette (b1c9f21) against an installed multigrain, and summarise.
# Run from the root of a checkout of trial_success_vignette: R_LIBS=<build> Rscript VG_knit.R <out.md>
# Run once with the branch's own build and once with main (508d0b7), then compare the two .md files.
suppressMessages(library(multigrain))
cat("multigrain", as.character(packageVersion("multigrain")), "\n")
tmp <- tempfile(); dir.create(tmp)
invisible(file.copy("vignettes/articles/trial_success.qmd", file.path(tmp, "trial_success.Rmd")))
invisible(file.copy("vignettes/articles/data", tmp, recursive = TRUE))
out <- normalizePath(commandArgs(TRUE)[1], mustWork = FALSE)
owd <- setwd(tmp)
knitr::opts_chunk$set(error = FALSE)          # chunks marked `error: true` keep their own setting
invisible(knitr::knit("trial_success.Rmd", out, quiet = TRUE))
setwd(owd)
md <- readLines(out)
cat("knitted without an unexpected error: TRUE\n")
cat("errors shown (chunks marked error: true):", sum(grepl("^#> Error", md)), "\n")
cat("compile messages printed:", sum(grepl("compiled and sourced successfully", md)), "\n")
cat("EXPECTED: no compile messages, since the article sets options(multigrain_verbosity = \"silent\")\n")
