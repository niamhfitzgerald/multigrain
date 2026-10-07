# DOC17g: sum_to_one_constraint = NA gives R's own error, not a message about the argument
# Run: Rscript DOC17g.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(0.5, 0.5)
G <- matrix(c(0, 1, 1, 0), 2)

na <- tryCatch(is_graph_valid(w, G, sum_to_one_constraint = NA),
               error = function(e) conditionMessage(e))
cat("sum_to_one_constraint = NA:            ", na, "\n")
two <- tryCatch(is_graph_valid(w, G, sum_to_one_constraint = c(TRUE, FALSE)),
                error = function(e) conditionMessage(e))
cat("sum_to_one_constraint = c(TRUE, FALSE):", two, "\n")
cat("EXPECTED: an error saying that `sum_to_one_constraint` must be TRUE or FALSE\n")
