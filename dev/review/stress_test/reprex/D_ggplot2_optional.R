# D_ggplot2_optional: the plot help calls ggplot2 an optional dependency; the package cannot load without it
# Run: Rscript D_ggplot2_optional.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["autoplot.multigrain_graph_optimal.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("require an optional", txt)
cat("help page says:", trimws(txt[i + 0:1]), "\n")

imports <- packageDescription("multigrain")$Imports
cat("ggplot2 under Imports in DESCRIPTION  :", grepl("ggplot2", imports), "\n")
cat("imported from ggplot2 by the NAMESPACE:", getNamespaceImports("multigrain")$ggplot2, "\n")
method <- deparse(multigrain:::autoplot.multigrain_graph_optimal)
cat("the autoplot method calls ggplot2::     :", any(grepl("ggplot2::", method)), "\n")

# What a user does have to do: attach ggplot2 before calling autoplot().
msg <- tryCatch(autoplot(graph_optimal_example), error = function(e) conditionMessage(e))
cat("autoplot() without library(ggplot2)   :", msg, "\n")
cat("EXPECTED: the help does not call a hard dependency optional, and says that\n")
cat("          autoplot() needs library(ggplot2)\n")
