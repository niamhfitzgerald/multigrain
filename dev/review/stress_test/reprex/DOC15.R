# DOC15: the get-started article has a dead relative link and a chunk with two labels
# Run from the repository root: Rscript DOC15.R   (base R only)
# fmt: skip file
art <- readLines("vignettes/articles/get-started.Rmd")

# pkgdown writes every file of vignettes/articles/ to articles/<name>.html, so a
# relative link in an article is resolved from articles/.
built <- sub("\\.(Rmd|qmd)$", ".html", list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$"))
i <- grep("\\]\\([A-Za-z_/-]+\\.html\\)", art)
target <- sub(".*\\]\\(([A-Za-z_/-]+\\.html)\\).*", "\\1", art[i])
cat(sprintf("line %d links to %-30s page exists: %s\n", i, target, target %in% built), sep = "")

# A chunk header takes one label; knitr reads "a, b" before the first option as one label.
cat("chunk headers with two labels:", grep("^```\\{r [A-Za-z_-]+, [A-Za-z_-]+,", art, value = TRUE), "\n")
cat("EXPECTED: every link resolves, and no chunk header has two labels\n")
