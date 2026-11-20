# fmt: skip file
# D8: knit every article of the package against an installed multigrain, with knitr (not Quarto). Chunks marked
# error: true keep their own setting; any other error stops the knit and is reported.
# Run from the repository root: R_LIBS=<build> Rscript D8_articles.R <out_dir>
suppressMessages(library(multigrain))
out_dir <- normalizePath(commandArgs(TRUE)[1], mustWork = FALSE); dir.create(out_dir, showWarnings = FALSE)
arts <- list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$", full.names = TRUE)
for (a in arts) {
    tmp <- tempfile(); dir.create(tmp)
    invisible(file.copy(list.files("vignettes/articles", full.names = TRUE), tmp, recursive = TRUE))
    src <- file.path(tmp, sub("\\.qmd$", ".Rmd", basename(a))); invisible(file.copy(a, src, overwrite = TRUE))
    md <- file.path(out_dir, sub("\\.(Rmd|qmd)$", ".md", basename(a)))
    owd <- setwd(tmp); knitr::opts_chunk$set(error = FALSE)
    t0 <- proc.time()[["elapsed"]]
    r <- tryCatch({ suppressMessages(knitr::knit(basename(src), md, quiet = TRUE)); "knitted" }, error = function(e) paste("ERROR:", conditionMessage(e)))
    setwd(owd)
    txt <- if (file.exists(md)) readLines(md) else character(0)
    cat(sprintf("%-24s %-8s %5.0f s  errors shown %d, warnings shown %d, compile messages %d\n", basename(a), if (startsWith(r, "ERROR")) "FAILED" else "knitted",
                proc.time()[["elapsed"]] - t0, sum(grepl("^(#>|##) Error", txt)), sum(grepl("^(#>|##) Warning", txt)), sum(grepl("compiled and sourced successfully", txt))))
    if (startsWith(r, "ERROR")) cat("   ", substr(gsub("\\s+", " ", r), 1, 300), "\n")
}
