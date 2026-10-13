# An early-claim bonus (value above 1 at the interim) is the natural way to
# write "a claim at the interim is worth S times a claim at the end", and it
# warns.
source("_common.R")
g <- trial_success_gsd(!!"d(t1) + d(t2) + d(t3)", d = c(2, 1), verbose = "silent")
# Warning: Discount table `d` contains values outside [0, 1]: 2.
# Workaround that rescales the whole gain:
g2 <- trial_success_gsd(!!"d(t1) + d(t2) + d(t3)", d = c(1, 0.5), verbose = "silent")
