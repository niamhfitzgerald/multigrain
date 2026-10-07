# B4: the simulators accept matrices that are not correlation matrices
# Run: Rscript B4.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Pairwise guesses for five endpoints; together they are not a correlation matrix.
S <- matrix(0.6, 5, 5)
diag(S) <- 1
S[1, 2] <- S[2, 1] <- -0.4
S[3, 4] <- S[4, 3] <- 0.95
cat("smallest eigenvalue:", round(min(eigen(S)$values), 3), "\n")

set.seed(1)
P <- withCallingHandlers(
    simulate_pvalues(rep(0.025, 5), corr_matrix = S, nsim = 2e5),   # five true nulls
    warning = function(w) {
        cat("only message:", conditionMessage(w), "\n")
        invokeRestart("muffleWarning")
    }
)
cat("P(p < 0.025) for the five true nulls:", round(colMeans(P < 0.025), 4), "\n")

# A covariance matrix passed by mistake
P2 <- simulate_pvalues(c(0.9, 0.9), corr_matrix = 4 * diag(2), nsim = 2e5)
cat("diagonal of 4, no message: power", round(colMeans(P2 < 0.025), 3), "for a nominal 0.9\n")
cat("EXPECTED: an error for both matrices; otherwise 0.025 for each true null",
    "and 0.9 for each power\n")
