# SR2: a mistyped rejection indicator in a stopping rule gets advice to inject a variable
# Run: Rscript SR2.R   (needs a gsd-build or gsd-build-spending build of multigrain at 8af8adb or later)
# fmt: skip file
library(multigrain)

for (cond in c("R1 and R2", "r0 or r1", "r01")) {
    msg <- tryCatch(stopping_rule_gsd(!!cond), error = function(e) conditionMessage(e))
    cat(sprintf("stopping_rule_gsd(\"%s\"):\n  %s\n", cond, gsub("\\s+", " ", msg)))
}
cat("EXPECTED: a message saying that rejection indicators are written r1, r2, ...\n")
cat("          (lower-case r, numbered from 1), not advice to inject `R1` with !!\n")
