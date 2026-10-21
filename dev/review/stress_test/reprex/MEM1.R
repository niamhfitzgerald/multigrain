# MEM1: the serial kernels compute matrix offsets in 32-bit integers
# Run from the repository root: Rscript MEM1.R   (reads src/graph_shortcut.cpp; allocates nothing)
# fmt: skip file
src <- trimws(readLines("src/graph_shortcut.cpp"))
cat("in graph_shortcut(), the serial fixed-sample kernel:\n")
for (pattern in c("N = pvals.nrow()", "; set < ", "p_ptr[set", "h_ptr[set")) {
    cat("   ", grep(pattern, src, fixed = TRUE, value = TRUE)[1], "\n")
}

n_trials <- 1e8                           # 1e8 trials of 22 hypotheses: 2.2e9 p-values, 17.6 GB
n_hyp <- 22
offset <- (n_trials - 1) + (n_hyp - 1) * n_trials      # `set + i * N` for the last p-value
as_int <- (offset + 2^31) %% 2^32 - 2^31               # the same sum in a 32-bit signed integer
cat("offset of the last p-value:      ", format(offset, big.mark = ",", scientific = FALSE), "\n")
cat("the same sum in a 32-bit integer:", format(as_int, big.mark = ",", scientific = FALSE), "\n")
cat("EXPECTED: `N` and `set` declared as R_xlen_t (64 bits), so that the offset cannot overflow\n")
