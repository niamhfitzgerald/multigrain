# B8: the help page of trial_success() is malformed and its examples do not parse
# Run from the repository root: Rscript B8.R   (reads man/ and R/; needs only base R)
# fmt: skip file
rd <- "man/trial_success.Rd"

# 1. Structure of the help file
problems <- capture.output(print(suppressWarnings(tools::checkRd(rd))))
problems <- grep("unexpected", problems, value = TRUE)
cat("structural problems reported by tools::checkRd():", length(problems), "\n")
cat(sprintf("  %s\n", problems), sep = "")

# 2. The examples, as R CMD check extracts them
ex <- tempfile(fileext = ".R")
suppressWarnings(tools::Rd2ex(rd, ex))
parsed <- tryCatch({ parse(ex); "yes" }, error = function(e) "no")
cat("examples parse:", parsed, "\n")

# 3. Typographic quotes (UTF-8 bytes e2 80 9c and e2 80 9d) in the roxygen
#    source the page is generated from
src <- readLines("R/trial_success.R", warn = FALSE)
curly <- grepl("\xe2\x80[\x9c\x9d]", src, useBytes = TRUE)
cat("lines of R/trial_success.R with typographic quotes:", which(curly), "\n")
cat("EXPECTED: no structural problem, examples that parse, and no such lines\n")
