# DOC1: the get-started article codes "both primaries" where its text says "at least one"
# Run from the repository root: Rscript DOC1.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

art <- readLines("vignettes/articles/get-started.Rmd")
i <- grep("at least one of the$", art)
cat("article text :", trimws(art[i + 0:2]), "\n")
code <- trimws(grep("r1 && r2|r1 \\|\\| r2", art, value = TRUE))
cat("article code :", code, "\n")

as_coded <- eval(parse(text = sprintf("trial_success(%s, verbose = 'silent')", code)))
as_text <- trial_success(0.25 * (2 * (r1 || r2) + r1 * r3 + r2 * r4), verbose = "silent")

# One trial: the first primary H1 and its secondary H3 are rejected, H2 and H4 are not.
rej <- matrix(c(TRUE, FALSE, TRUE, FALSE), nrow = 1)
cat("score of that trial, measure as coded     :", as_coded$func(rej), "\n")
cat("score of that trial, measure as described :", as_text$func(rej), "\n")

g <- readRDS("vignettes/articles/data/get-started-custom-power-graph.rds")
cat("measure behind the results on the page    :", g$trial_success$objective, "\n")
cat("EXPECTED: text, formula, code and stored results use one measure (0.75 for this trial if it is 'at least one')\n")
