# D_local_weights: the internal calc_local_weights() crashes for zero hypotheses and reads past a small matrix
# Run: Rscript D_local_weights.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

w <- c(0.5, 0.3, 0.2)
G <- rbind(c(0, 0.5, 0.5),
           c(0.5, 0, 0.5),
           c(0.5, 0.5, 0))
right <- multigrain:::calc_local_weights(w, G)
small <- tryCatch(multigrain:::calc_local_weights(w, G[1:2, 1:2]),      # 2 x 2 matrix, 3 weights
                  error = function(e) conditionMessage(e))
cat("3 weights with a 2 x 2 matrix:", if (is.matrix(small)) "no error" else small, "\n")
if (is.matrix(small)) {
    cat("rows that differ from the 3 x 3 call:", sum(rowSums(abs(small - right)) > 0), "of", nrow(right), "\n")
}

# Zero hypotheses end the R session, so the call is made in a child process.
code <- 'multigrain:::calc_local_weights(numeric(0), matrix(0, 0, 0))'
status <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
                  stdout = FALSE, stderr = FALSE)
cat("child process with zero hypotheses: exit status", status, "(139 = segmentation fault)\n")
cat("EXPECTED: an R error from both calls\n")
