# MEM4: graph_violation_score_cpp() reads past a transition matrix smaller than the weight vector
# Run: Rscript MEM4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- rep(1 / 20, 20)                      # 20 hypotheses
G_small <- matrix(0.25, 5, 5)             # a matrix for 5
G_right <- matrix(0.25, 20, 20)

score <- tryCatch(multigrain:::graph_violation_score_cpp(w, G_small),
                  error = function(e) conditionMessage(e))
cat("score with the 5 x 5 matrix:  ", format(score), "\n")
cat("an error was raised:          ", is.character(score), "\n")
cat("score with a 20 x 20 matrix:  ", multigrain:::graph_violation_score_cpp(w, G_right), "\n")
cat("EXPECTED: an error for the 5 x 5 matrix, which is too small for 20 weights\n")
