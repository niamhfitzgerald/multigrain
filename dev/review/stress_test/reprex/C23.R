# C23: an epsilon edge below about 1e-13 gives wrong local levels
# Run: Rscript C23.R   (needs the gsd-build build of multigrain)
# fmt: skip file
library(multigrain)

# Two primary hypotheses pass 1 - e to each other and e to their own secondary.
graph <- function(e) rbind(c(0, 1 - e, e, 0),
                           c(1 - e, 0, 0, e),
                           c(0, 1, 0, 0),
                           c(1, 0, 0, 0))
w <- c(0.5, 0.5, 0, 0)

# H1 and H2 are rejected (p = 0). H3 then holds alpha / 2 = 0.0125, whatever e is.
h3_rejected <- function(e, p3) {
    calc_power_pvals(rbind(c(0, 0, p3, 1)), w, graph(e))$local_power[3] == 1
}
for (e in c(1e-6, 1.2e-16, 1e-300)) {
    cat("e =", format(e), ": graph valid:", is_graph_valid(w, graph(e)),
        " H3 rejected at p = 0.012:", h3_rejected(e, 0.012),
        " at p = 0.013:", h3_rejected(e, 0.013), "\n")
}
cat("EXPECTED: TRUE at p = 0.012 and FALSE at p = 0.013 for every e, or a warning that the edge is too small\n")
