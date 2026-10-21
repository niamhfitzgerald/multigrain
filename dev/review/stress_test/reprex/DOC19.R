# DOC19: text errors in the Getting Started and Graph constraints articles
# Run from the repository root: Rscript DOC19.R   (base R only)
# fmt: skip file
files <- c("vignettes/articles/get-started.Rmd", "vignettes/articles/graph_constraint.qmd")
for (f in files) {
    x <- readLines(f, warn = FALSE)
    pats <- c("two-arm", "means means", "even thought", "^\\[`simulate_pvalues\\(\\)`\\]")
    hit <- sort(unique(unlist(lapply(pats, grep, x))))
    for (h in hit) cat(sprintf("%s:%d: %s\n", basename(f), h, substr(trimws(x[h]), 1, 90)))
}
cat("EXPECTED: \"a three-arm parallel confirmatory clinical trial\", \"means\", \"even though\", and no stray brackets\n")
