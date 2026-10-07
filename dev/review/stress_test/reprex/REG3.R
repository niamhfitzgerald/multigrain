# REG3: gsd-build still reports version 0.3.0, the number of the tag v0.3.0
# Run from the repository root: Rscript REG3.R   (needs git and the tag v0.3.0; base R only)
# fmt: skip file
git <- function(...) system2("git", c(...), stdout = TRUE)

at_tag <- grep("^Version:", git("show", "v0.3.0:DESCRIPTION"), value = TRUE)
cat("at the tag v0.3.0, DESCRIPTION has:", at_tag, "\n")
cat("in this checkout, DESCRIPTION has :", "Version:", read.dcf("DESCRIPTION", "Version"), "\n")

since <- git("log", "--oneline", "v0.3.0..HEAD", "--", "R", "src")
cat("commits after the tag that change R/ or src/:", length(since), "\n")
cat("one of them:", grep("fixes #12", since, value = TRUE), "\n")

fix <- "independently sample from the full p-value simulation matrix"
cat("that fix is listed in NEWS.md at the tag:", any(grepl(fix, git("show", "v0.3.0:NEWS.md"))), "\n")
news <- readLines("NEWS.md")
heads <- grep("^# ", news)
cat("heading above it in NEWS.md here      :", news[max(heads[heads < grep(fix, news)])], "\n")
cat("EXPECTED: a development version after the tag, and that fix under the development heading\n")
