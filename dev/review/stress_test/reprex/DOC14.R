# DOC14: replacing any other element of a graph constraint gives "object 'output' not found"
# Run: Rscript DOC14.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

con <- graph_constraint(hyp_constraint = c(NA, 0.4, NA))

# the documented route works
con$hyp_constraint <- c(NA, NA, NA)
cat("con$hyp_constraint <- c(NA, NA, NA): weights now", paste(con$hyp_constraint, collapse = " "), "\n")

# a slip: the tolerance is an argument of graph_constraint(), not an element
msg <- tryCatch({
    con$tolerance <- 1e-6
    "accepted"
}, error = function(e) conditionMessage(e))
cat("con$tolerance <- 1e-6:", msg, "\n")
cat("EXPECTED: an error saying that only hyp_constraint and trans_constraint can be replaced\n")
