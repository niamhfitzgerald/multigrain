# C13: a long flat sum cannot be turned into a gain: the C stack runs out
# Run: Rscript C13.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 600 terms, as in a utility table with one term per rejection pattern
terms <- sprintf("0.5 * r%d", rep(1:3, length.out = 600))

flat <- paste(terms, collapse = " + ")
msg <- tryCatch({ trial_success(!!flat, verbose = "silent"); "built" },
                error = function(e) conditionMessage(e))
cat("600 terms as one flat sum      :", msg, "\n")

# The same terms, 20 to a pair of parentheses
groups <- tapply(terms, rep(1:30, each = 20), paste, collapse = " + ")
grouped <- paste0("(", groups, ")", collapse = " + ")
g <- trial_success(!!grouped, verbose = "silent")
cat("600 terms in 30 groups of 20   : built; value with every hypothesis rejected",
    g$func(matrix(TRUE, 1, 3)), " (correct: 300)\n")
cat("EXPECTED: the flat sum is built too, or the error says to group the terms\n")
