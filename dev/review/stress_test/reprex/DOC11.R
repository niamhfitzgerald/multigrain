# DOC11: the help text of sum_to_one_constraint reads as the opposite of what the argument does
# Run: Rscript DOC11.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

rd <- tools::Rd_db("multigrain")[["is_graph_valid.Rd"]]
txt <- capture.output(tools::Rd2txt(rd, options = list(underline_titles = FALSE)))
i <- grep("^sum_to_one_constraint:", txt)
cat("?is_graph_valid says:", txt[i:(i + 3)], sep = "\n")

w <- c(1, 0, 0)                              # fixed sequence H1 -> H2 -> H3
G <- rbind(c(0, 1, 0),
           c(0, 0, 1),
           c(0, 0, 0))                       # the last row sums to 0
cat("fixed sequence, sum_to_one_constraint = TRUE (the default):",
    suppressWarnings(is_graph_valid(w, G, sum_to_one_constraint = TRUE)), "\n")
cat("fixed sequence, sum_to_one_constraint = FALSE:             ",
    is_graph_valid(w, G, sum_to_one_constraint = FALSE), "\n")
cat("EXPECTED: text saying that TRUE requires every row to sum to 1 and FALSE allows less\n")
