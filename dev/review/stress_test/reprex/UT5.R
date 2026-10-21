# UT5: a stale Quarto intermediate of the trial success article is committed
# Run from the repository root: Rscript UT5.R   (needs git; base R only)
# fmt: skip file
f <- "vignettes/articles/trial_success.rmarkdown"
cat("committed:", file.exists(f), "\n")
rm <- readLines(f, warn = FALSE)
qmd <- readLines("vignettes/articles/trial_success.qmd", warn = FALSE)
for (s in c("does not exist yet", "0.5833")) {
    cat(sprintf("%-22s in .rmarkdown: %-5s in .qmd: %s\n", paste0("\"", s, "\""), any(grepl(s, rm, fixed = TRUE)), any(grepl(s, qmd, fixed = TRUE))))
}
ign <- c(readLines(".gitignore", warn = FALSE), readLines(".Rbuildignore", warn = FALSE))
cat("*.rmarkdown in .gitignore or .Rbuildignore:", any(grepl("rmarkdown", ign, fixed = TRUE)), "\n")
cat("EXPECTED: no .rmarkdown file in the repository, and *.rmarkdown ignored\n")
