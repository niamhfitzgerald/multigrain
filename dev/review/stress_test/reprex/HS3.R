# HS3: an empty or blank id is accepted and gives a parameter with no name
# Run: Rscript HS3.R   (needs a gsd-build-spending build of multigrain)
# fmt: skip file
suppressMessages(library(multigrain))
for (id in c("", "  ")) {
    tag <- tryCatch(sf_hsd_opt(id = id, bounds = c(-1, 0), step = 0.5), error = function(e) conditionMessage(e))
    cat(sprintf("sf_hsd_opt(id = \"%s\"): %s\n", id, if (is.function(tag)) "accepted" else tag))
}
set.seed(1)
raw  <- array(stats::runif(200 * 2 * 2), dim = c(200L, 2L, 2L))
spec <- transform_pvalues_gsd(raw, info_frac = c(0.5, 1), grid_size = 64L,
                              spending = list(gsDesign::sfLDOF, sf_hsd_opt(id = "", bounds = c(-1, 0), step = 0.5)))
cat(grep("sfHSD|bounds", capture.output(print(spec)), value = TRUE), sep = "\n")
v <- c(-0.5); names(v) <- ""
cat("resolve_pvalues_gsd() with that name:", tryCatch({ resolve_pvalues_gsd(spec, v); "ran" },
    error = function(e) gsub("\\s+", " ", paste(conditionMessage(e), collapse = " "))), "\n")
cat("EXPECTED: an error from sf_hsd_opt(): id must be a non-empty string\n")
