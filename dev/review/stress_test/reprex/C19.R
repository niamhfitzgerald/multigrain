# C19: every gain keeps a shared library loaded and files on disk until the session ends
# Run: Rscript C19.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

loaded <- function() sum(grepl("^sourceCpp", names(getLoadedDLLs())))
on_disk <- function() {
    files <- list.files(tempdir(), recursive = TRUE, full.names = TRUE)
    c(files = length(files), MB = round(sum(file.size(files)) / 1e6, 1))
}
dll_before <- loaded()
disk_before <- on_disk()

# Two scenarios of a sweep over a weight; each gain is dropped after use
for (w in c(0.4, 0.6)) {
    g <- trial_success(!!w * r1 + r2, verbose = "silent")
    rm(g)
}
invisible(gc())

cat("gain libraries loaded, before and after 2 gains were built and discarded:",
    dll_before, loaded(), "\n")
cat("left in tempdir():", on_disk()[["files"]] - disk_before[["files"]], "files,",
    on_disk()[["MB"]] - disk_before[["MB"]], "MB\n")
cat("limit on loaded libraries (R_MAX_NUM_DLLS):",
    Sys.getenv("R_MAX_NUM_DLLS", "not set, so R's default of 614 at most"), "\n")
cat("EXPECTED: the library of a discarded gain is released, or the help states the limit\n")
