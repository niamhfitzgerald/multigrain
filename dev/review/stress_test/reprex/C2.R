# C2: two analyses with nearly the same information abort with a misleading message
# Run: Rscript C2.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)
library(gsDesign)

info <- c(0.998, 1)                        # two analyses 0.2% of the information apart
set.seed(1)
raw <- array(runif(40), dim = c(20, 1, 2))
msg <- tryCatch(
    {
        transform_pvalues_gsd(raw, info_frac = info, spending = sfLDOF)
        "no error"
    },
    error = function(e) conditionMessage(e)
)
cat("transform_pvalues_gsd() with sfLDOF says:\n", msg, "\n\n")

# What gsBound1() returns for these analyses at one small level of the table
level <- 5e-12
spend <- sfLDOF(level, info)$spend
fit <- gsBound1(theta = 0, I = info, a = c(-20, -20), probhi = diff(c(0, spend)))
cat("gsBound1() at a level of", level, ": error flag", fit$error,
    ", final nominal boundary", signif(pnorm(fit$b[2], lower.tail = FALSE), 3), "\n")
cat("EXPECTED: an error that names gsBound1() and the two information fractions,",
    "or a transform (sfLDOF is well ordered)\n")
