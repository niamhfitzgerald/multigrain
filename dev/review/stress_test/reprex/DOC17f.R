# DOC17f: plot(x, root = 7) on a graph with 4 hypotheses gives a raw igraph error
# Run: Rscript DOC17f.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

pdf(NULL)
cat("hypotheses in the bundled example graph:", length(graph_optimal_example$hyp_weight), "\n")

# the help example: nodes 1 and 2 as root
p <- plot(graph_optimal_example, root = c(1, 2))
cat("plot(graph_optimal_example, root = c(1, 2)): works, class", class(p)[1], "\n")

# a node that does not exist
msg <- tryCatch({
    plot(graph_optimal_example, root = 7)
    "accepted"
}, error = function(e) conditionMessage(e))
cat("plot(graph_optimal_example, root = 7):", msg, "\n")
cat("EXPECTED: an error saying that `root` must lie between 1 and 4\n")
