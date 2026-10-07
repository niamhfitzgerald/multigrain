# D_graphics_undeclared: plot is imported from graphics, which DESCRIPTION does not declare
# Run: Rscript D_graphics_undeclared.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

imp <- getNamespaceImports("multigrain")
used <- setdiff(unique(names(imp)), "base")
d <- packageDescription("multigrain")
declared <- sub("\\s*\\(.*", "", trimws(strsplit(paste(d$Imports, d$Depends, sep = ","), ",")[[1]]))

cat("namespaces the package imports from:", paste(sort(used), collapse = ", "), "\n")
cat("imported and not declared in DESCRIPTION:", setdiff(used, declared), "\n")
cat("what is imported from it:", unlist(imp[names(imp) == "graphics"]), "\n")
cat("where the plot() generic lives in this R:", environmentName(environment(plot)), "\n")
cat("EXPECTED: every namespace in NAMESPACE is under Imports, as stats and utils are\n")
