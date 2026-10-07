# DOC17h: the graph constraint article calls the argument `m`; it is `num_hyp`
# Run from the repository root: Rscript DOC17h.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

art <- readLines("vignettes/articles/graph_constraint.qmd")
i <- grep("by supplying the number of hypotheses", art)
cat(sprintf("article, line %d: %s\n", i, sub("\\. In this case.*", ".", art[i])))
cat("arguments of graph_constraint_free():", names(formals(graph_constraint_free)), "\n")

msg <- tryCatch({ graph_constraint_free(m = 3); "no error" }, error = function(e) conditionMessage(e))
cat("graph_constraint_free(m = 3):", msg, "\n")
cat("graph_constraint_free(num_hyp = 3): a constraint on",
    length(graph_constraint_free(num_hyp = 3)$hyp_constraint), "hypotheses\n")
cat("EXPECTED: the article names the argument `num_hyp`\n")
