# DOC6: a roxygen-style link in the trial success article is shown as literal text
# Run from the repository root: Rscript DOC6.R   (base R; uses pandoc when it is on the PATH)
# fmt: skip file
art <- readLines("vignettes/articles/trial_success.qmd")

# [text][pkg::topic] is a link only inside roxygen comments. In Markdown it is a
# reference link, which needs a line "[pkg::topic]: <address>" somewhere in the file.
i <- grep("\\]\\[[A-Za-z.]+::[^]]+\\]", art)
cat("roxygen-style links in the article:", length(i), "\n")
if (length(i)) cat(sprintf("  line %d: %s\n", i, art[i]), sep = "")
cat("reference definitions in the article:", sum(grepl("^\\[[^]]+\\]:\\s", art)), "\n")

if (length(i) && nzchar(Sys.which("pandoc"))) {
    html <- system2("pandoc", c("-f", "markdown", "-t", "html"), input = art[i], stdout = TRUE)
    cat("pandoc turns the line into:", html, "\n")
}
cat("EXPECTED: no such link; a Markdown link to the rlang page is rendered as <a href=...>\n")
