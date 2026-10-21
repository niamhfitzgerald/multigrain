# DOC18: the README calls Getting Started a walk-through of its example, but the two use different inputs
# Run from the repository root: Rscript DOC18.R   (base R only)
# fmt: skip file
readme <- readLines("README.Rmd", warn = FALSE)
art <- readLines("vignettes/articles/get-started.Rmd", warn = FALSE)
cat("README links Getting Started as:", regmatches(readme, regexpr("full walk-through.*$", readme)), "\n\n")
show <- function(lab, x, pat) cat(sprintf("%-28s %s\n", lab, trimws(grep(pat, x, value = TRUE)[1])))
show("README nominal powers:", readme, "^power_nominal <- c\\(")
show("article nominal powers:", art, "^power_vector <- c\\(")
show("README nsim:", readme, "nsim = ")
show("article nsim:", art, "nsim = ")
show("README success measure:", readme, "2 \\* \\(r1")
show("article success measure:", art, "2 \\* \\(r1")
cat("README correlation of H1 and H3:", sub(".*1\\.0, 0\\.5, ([0-9.]+),.*", "\\1", grep("1\\.0, 0\\.5,", readme, value = TRUE)[1]),
    "  article:", sub(".*c\\(1, 0\\.5, ([0-9.]+),.*", "\\1", grep("c\\(1, 0\\.5,", art, value = TRUE)[1]), "\n")
cat("EXPECTED: the same inputs in both, or no claim that one walks through the other\n")
