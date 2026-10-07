# DOC7: NEWS.md does not announce the group sequential functions or the gsDesign dependency
# Run from the repository root: Rscript DOC7.R   (base R only)
# fmt: skip file
news <- readLines("NEWS.md")
dev <- news[seq_len(grep("^# multigrain [0-9]", news)[1] - 1)]   # the development section
cat("headings in the development section:", grep("^## ", dev, value = TRUE), "\n")

ns <- readLines("NAMESPACE")
gsd <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(.*_gsd\\)$", ns, value = TRUE))
for (f in gsd) {
    cat(sprintf("%-24s mentioned in the development section: %s\n", f,
                any(grepl(paste0(f, "()"), dev, fixed = TRUE))))
}
cat("gsDesign in Imports of DESCRIPTION      :",
    grepl("gsDesign", read.dcf("DESCRIPTION", "Imports")), "\n")
cat("gsDesign mentioned in the development section:", any(grepl("gsDesign", dev)), "\n")
cat("EXPECTED: a 'New functionality' heading that names all six functions and the new dependency\n")
