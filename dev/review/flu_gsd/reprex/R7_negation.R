# There is no negation. "Did not stop" has to be written as (1 - stop).
source("_common.R")
try(trial_success_gsd(!!"(!(t1 == 1)) * (r1 + r2 + r3)", K = 2, verbose = "silent"))
ok <- trial_success_gsd(!!"(1 - (t1 == 1)) * (r1 + r2 + r3)", K = 2, verbose = "silent")
try(trial_success_gsd(!!"max((t1 == 1), (t2 == 1)) * (r1 + r2 + r3)", K = 2, verbose = "silent"))
