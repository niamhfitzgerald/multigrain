# ENV01: a decimal comma in the session changes the gain that is compiled
# Run: Rscript ENV01.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

x <- matrix(TRUE, 1, 3)        # all three rejected: (r1 || r2) + 0.5 * r3 is 1.5

old <- options(OutDec = ",")   # a session that prints decimal commas
g <- trial_success((r1 || r2) + 0.5 * r3, verbose = "silent")
options(old)
cat("built under options(OutDec = \",\")\n")
cat("  objective stored in the object:", g$objective, "\n")
cpp <- grep("total \\+=", strsplit(g$cpp_code, "\n")[[1]], value = TRUE)
cat("  compiled C++:", trimws(sub(";.*", "", cpp)), "\n")
cat("  value when all three are rejected:", g$func(x), "  (correct: 1.5)\n")

# The same defect through the numeric locale, if this machine has one with a comma
for (loc in c("de_DE.UTF-8", "de_DE", "fr_FR.UTF-8", "German_Germany.utf8", "German")) {
    suppressWarnings(Sys.setlocale("LC_NUMERIC", loc))
    if (sprintf("%.1f", 0.5) == "0,5") break
}
if (sprintf("%.1f", 0.5) == "0,5") {
    g2 <- trial_success("(r1 || r2) + 0.5 * r3", verbose = "silent")
    invisible(Sys.setlocale("LC_NUMERIC", "C"))
    cat("built from a string under LC_NUMERIC =", loc, "\n")
    cat("  value when all three are rejected:", g2$func(x), "  (correct: 1.5)\n")
} else {
    cat("LC_NUMERIC part not run: no locale with a decimal comma is installed on this machine\n")
}
cat("EXPECTED: 1.5 from every gain, whatever the session prints\n")
