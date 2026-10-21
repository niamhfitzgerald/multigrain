# DOC13: nothing a user reads says that defining a gain needs a C++ toolchain every time
# Run from the repository root: Rscript DOC13.R   (reads the sources; needs only base R)
# fmt: skip file

# Where the package compiles C++ when a user calls it, not when it is installed
for (f in c("R/trial_success.R", "R/trial_success_gsd.R")) {
    cat(sprintf("%s: sourceCpp() called at line %s\n", f,
                paste(grep("^ *sourceCpp\\(", readLines(f, warn = FALSE)), collapse = ", ")))
}

# What the documentation says about it
cat("DESCRIPTION, SystemRequirements:", read.dcf("DESCRIPTION", "SystemRequirements"), "\n")
for (f in c("README.md", "man/trial_success.Rd", "man/trial_success_gsd.Rd")) {
    hits <- grep("toolchain|compiler|Rtools|Xcode", readLines(f, warn = FALSE), ignore.case = TRUE)
    cat(sprintf("%-25s lines that mention a compiler or a toolchain: %d\n", f, length(hits)))
}
cat("EXPECTED: the requirement stated in the help of both constructors\n")
