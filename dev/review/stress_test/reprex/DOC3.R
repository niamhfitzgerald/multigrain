# DOC3: four group sequential help topics are missing from the pkgdown reference index
# Run from the repository root: Rscript DOC3.R   (base R only)
# fmt: skip file
ns <- readLines("NAMESPACE")
exported <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))

yml <- readLines("_pkgdown.yml")
listed <- sub("^\\s*-\\s+", "", grep("^\\s+-\\s+[A-Za-z_.]+\\s*$", yml, value = TRUE))

# graph_optimise_gsd and graph_optimize_gsd share one help page, so five names are four topics
cat("exported functions:", length(exported), "\n")
cat("exported and not in the reference index of _pkgdown.yml:\n ",
    paste(setdiff(exported, listed), collapse = ", "), "\n")
cat("EXPECTED: none. pkgdown stops with 'All topics must be included in reference index'\n")
cat("          when a help topic that is not marked internal has no entry.\n")
