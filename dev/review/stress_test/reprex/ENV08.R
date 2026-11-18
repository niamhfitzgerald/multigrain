# ENV08: the old name of the verbosity option is ignored without a message
# Run: Rscript ENV08.R   (about 5 s)
# fmt: skip file
suppressMessages(library(multigrain))
options(multigrain_verbosity = "silent")          # the name used up to multigrain 1.0.0
cat("multigrain_verbosity() returns:", multigrain_verbosity(), "\n")
out <- capture.output(g <- trial_success(r1 + r2), type = "message")
cat("messages printed by trial_success(r1 + r2):", length(out), "\n")
if (length(out)) cat("  first:", out[1], "\n")
cat("EXPECTED: \"silent\" and 0 messages, or a warning that the option was renamed to multigrain.verbosity\n")
