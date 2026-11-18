# HS10: the article's data script stops at its report on R older than 4.4
# Run from the repository root: Rscript HS10.R   (base R only)
# fmt: skip file
src <- readLines("data-raw/gsd-joint-spending-vignette.R")
i <- grep("%||%", src, fixed = TRUE)
cat("lines using %||%:", i, "\n")
cat("R version:", as.character(getRversion()), "  %||% in base R:", exists("%||%", envir = baseenv()), "\n")
cat("rlang or a local definition loaded by the script:", any(grepl("library\\(rlang\\)|`%\\|\\|%` <-|%\\|\\|% <-", src)), "\n")
cat("EXPECTED: the script defines %||% or calls rlang::`%||%`, so it runs on every R the package supports (R >= 4.1)\n")
