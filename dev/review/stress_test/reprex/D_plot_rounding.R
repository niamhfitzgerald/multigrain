# D_plot_rounding: from 5 hypotheses up, plot() labels an edge of 0.001 as 0
# Run: Rscript D_plot_rounding.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# 5 hypotheses. H1 has weight 0.004 and passes 0.001 to H2 (an epsilon edge) and 0.999 to H3.
tc <- rbind(c(0, 0.001, 0.999, 0, 0), c(NA, 0, NA, NA, NA), c(NA, NA, 0, NA, NA),
            c(NA, NA, NA, 0, NA), c(NA, NA, NA, NA, 0))
con <- graph_constraint(c(0.004, 0.996, 0, 0, 0), tc)

pdf(NULL)
layers <- ggplot2::ggplot_build(plot(con))$data    # layer 1: edges; layer 3: node labels
edges <- unique(layers[[1]][, c("from", "to", "label")])
nodes <- sub("\n", " ", layers[[3]]$label)

cat("label drawn on the edge H1 -> H2 (value 0.001):", edges$label[1], "\n")
cat("label drawn on the edge H1 -> H3 (value 0.999):", edges$label[2], "\n")
cat("labels drawn in the nodes H1 (0.004) and H2 (0.996):", nodes[1], "|", nodes[2], "\n")
cat("EXPECTED: labels that tell 0.001 from 0 and 0.999 from 1, for example <0.01 and >0.99\n")
