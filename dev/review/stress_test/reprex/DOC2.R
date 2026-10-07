# DOC2: the results shown in the get-started article are stored objects in an old layout
# Run from the repository root: Rscript DOC2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

old <- readRDS("vignettes/articles/data/get-started-avg-power-graph.rds")
cur <- graph_optimal_example   # an object in the layout graph_optimise() returns today

cat("fields, article object :", names(old), "\n")
cat("fields, current object :", names(cur), "\n")
cat("power,  article object :", names(old$power), "\n")
cat("power,  current object :", names(cur$power), "\n")
cat("class of the gain      :", class(old$trial_success), "(current:", class(cur$trial_success), ")\n")
cat("solution source        :", old$solution$opt_source, "(current:", cur$solution$opt_source, ")\n")
cat("graph_optimal_get_control() is NULL:", is.null(graph_optimal_get_control(old)), "\n\n")

# The article shows the code summary(graph_average_power). On the stored object it gives:
out <- capture.output(summary(old))
cat(out[grep("Power metrics", out):length(out)], sep = "\n")
cat("EXPECTED: the four power lines under 'Power metrics', the gain, the constraints and a control object,\n")
cat("          as summary(graph_optimal_example) and graph_optimal_get_control(graph_optimal_example) give\n")
