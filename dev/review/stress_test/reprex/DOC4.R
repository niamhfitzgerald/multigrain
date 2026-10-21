# DOC4: a sentence of ?trial_success is cut off after "60"
# Run from the repository root: Rscript DOC4.R   (reads man/ and R/; needs only base R)
# fmt: skip file
src <- readLines("R/trial_success.R", warn = FALSE)
rd <- readLines("man/trial_success.Rd", warn = FALSE)
cat("roxygen source:", grep("each at 60", src, value = TRUE), "\n")
cat("help file     :", grep("each at 60", rd, value = TRUE), "\n")

page <- capture.output(suppressWarnings(tools::Rd2txt("man/trial_success.Rd")))
cat("rendered help :", trimws(grep("each at 60", page, value = TRUE)), "\n")
cat("EXPECTED: ... hypotheses each at 60% power returns approximately 2.4, not 0.6.\n")
