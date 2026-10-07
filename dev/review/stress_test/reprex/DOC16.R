# DOC16: the website dependencies list two unused packages; version and word list are out of step
# Run from the repository root: Rscript DOC16.R   (base R only)
# fmt: skip file
d <- read.dcf("DESCRIPTION")
needs <- trimws(strsplit(d[, "Config/Needs/website"], ",")[[1]])
cat("Config/Needs/website:", paste(needs, collapse = ", "), "\n")

# What the site builds: the articles, the README and the examples of the help pages.
files <- c(list.files("vignettes/articles", pattern = "\\.(Rmd|qmd)$", full.names = TRUE),
           "README.Rmd", list.files("man", pattern = "\\.Rd$", full.names = TRUE))
text <- unlist(lapply(files, readLines, warn = FALSE))
for (p in needs) {
    used <- sum(grepl(paste0("\\b", p, "::|library\\(", p, "\\)"), text))
    cat(sprintf("  %-13s lines that call it (pkg:: or library()): %d\n", p, used))
}
cat("Version:", d[, "Version"], "  first heading of NEWS.md:", readLines("NEWS.md", n = 1), "\n")
cat("EXPECTED: only packages the site uses, and a development version number under a development heading\n")
