# C22: is_graph_valid() stops on a missing value; normalise_sum() keeps negative weights
# Run: Rscript C22.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

G <- rbind(c(0, 0.5, 0.5),
           c(0.5, 0, 0.5),
           c(0.5, 0.5, 0))
valid <- tryCatch(is_graph_valid(c(0.5, NA, 0.5), G), error = function(e) conditionMessage(e))
cat("is_graph_valid(c(0.5, NA, 0.5), G):", valid, "\n")

norm <- tryCatch(normalise_sum(c(1, -0.999)), error = function(e) conditionMessage(e))
cat("normalise_sum(c(1, -0.999)):       ", norm, "\n")
cat("EXPECTED: FALSE with a warning from is_graph_valid(), as its help says; an error from normalise_sum()\n")
