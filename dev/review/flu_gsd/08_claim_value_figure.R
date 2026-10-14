# What an early claim has to be worth: the round-2 (per-claim timing) version
# of the round-1 "What an early finish has to be worth" chart.
#
# x axis: S, the value of a claim made at the end of season 1 relative to the
# same claim made at the end of season 2. y axis: expected value with
# highest-level claim values (10% dropout a season, protocol stopping rule).
#
# For a fixed design the value is linear in S:
#   value(S) = S * E[L1] + E[(1 - stop) * (L2 - L1)]
# where L1 and L2 are the levels reached by season 1 and season 2. So each
# fixed design is drawn as an exact line, and the "best for each S" curves are
# the upper envelope of the designs the optimiser found at S = 1, 1.5 and 2.
# The standard (single-analysis) design makes no season-1 claims, so it is flat.
#
# Run from this folder: Rscript 08_claim_value_figure.R
source("00_setup.R")

rule <- "protocol"
S_opt <- c(1, 1.5, 2)
S_grid <- seq(1, 2, by = 0.005)

z_test  <- simulate_z(1e5, test_seed)
z_train <- simulate_z(1e5, train_seed)

## Per-trial pieces for a group sequential design -----------------------------
pieces <- function(pv, g) {
  tm <- decision_times(pv, g)
  R1 <- tm == 1L; colnames(R1) <- ids
  R2 <- tm > 0L
  stop <- stop_rules[[rule]]$fun(R1)
  L1 <- levels_value(R1); L2 <- levels_value(R2)
  list(a = L1, b = (1 - stop) * (L2 - L1), p_stop = mean(stop))
}
value_at <- function(pc, S) S * pc$a + pc$b            # per-trial value at S

## Standard design: one analysis at the end of season 2, full alpha ----------
single_look <- function(z) {
  raw <- array(pnorm(z$z2, lower.tail = FALSE), c(nrow(z$z2), m, 1L))
  transform_pvalues_gsd(raw, info_frac = 1, spending = gsDesign::sfLDOF, alpha = alpha)
}
pv_std_train <- single_look(z_train)
pv_std_test  <- single_look(z_test)
gain_std <- trial_success_gsd(!!levels_expr(by_s2), K = 1, verbose = "silent")
std_runs <- optimise_graph(pv_std_train, gain_std, "standard__levels")
g_std <- as_graph(best_run(std_runs))
std_val <- levels_value(decision_times(pv_std_test, g_std) > 0L)
std_prot_val <- levels_value(decision_times(pv_std_test, protocol_graph) > 0L)

## Group sequential designs ----------------------------------------------------
pv_prot <- make_pvals(z_test, spending_set("protocol"))
designs <- list()
designs[["protocol"]] <- list(pieces(pv_prot, protocol_graph))

# Best graph for each S, protocol spending (task 2 runs)
designs[["graph"]] <- lapply(S_opt, function(S) {
  runs <- lapply(optim_seeds, function(s) readRDS(run_path(sprintf("%s__s%d.rds", scenario_tag(rule, "protocol", S), s))))
  pieces(pv_prot, as_graph(best_run(runs)))
})

# Best graph and shared gamma for each S (task 5, chosen inside multigrain)
designs[["graph_gamma"]] <- lapply(S_opt, function(S) {
  runs <- lapply(optim_seeds, function(s) readRDS(run_path(sprintf("gammapkg__%s__S%.2f__shared__s%d.rds", rule, S, s))))
  best <- best_run(runs)
  pv <- make_pvals(z_test, spending_set(gamma = best$gamma))
  pieces(pv, as_graph(best))
})

## Curves: exact lines, envelope for the "best" series ------------------------
curve <- function(set, S) max(vapply(set, function(pc) mean(value_at(pc, S)), 1))
lines <- rbindlist(list(
  data.table(S = S_grid, value = mean(std_val), series = "standard"),
  data.table(S = S_grid, value = sapply(S_grid, curve, set = designs$protocol), series = "protocol"),
  data.table(S = S_grid, value = sapply(S_grid, curve, set = designs$graph), series = "graph"),
  data.table(S = S_grid, value = sapply(S_grid, curve, set = designs$graph_gamma), series = "graph_gamma")
))

# Points at S = 1, 1.5, 2: the design optimised for that S, with Monte Carlo SE
# and the paired difference from the standard design.
pt <- function(series, pc, S) {
  v <- value_at(pc, S)
  data.table(S = S, series = series, value = mean(v), se = sd(v) / sqrt(length(v)),
             diff_vs_standard = mean(v - std_val), se_diff = sd(v - std_val) / sqrt(length(v)),
             p_stop = pc$p_stop)
}
points <- rbindlist(c(
  lapply(S_opt, function(S) data.table(S = S, series = "standard", value = mean(std_val),
                                       se = sd(std_val) / sqrt(length(std_val)),
                                       diff_vs_standard = 0, se_diff = 0, p_stop = 0)),
  lapply(S_opt, function(S) pt("protocol", designs$protocol[[1]], S)),
  lapply(seq_along(S_opt), function(i) pt("graph", designs$graph[[i]], S_opt[i])),
  lapply(seq_along(S_opt), function(i) pt("graph_gamma", designs$graph_gamma[[i]], S_opt[i]))
))

# Break-even: where each group sequential curve meets the standard design
break_even <- lines[series != "standard", {
  d <- value - mean(std_val)
  if (all(d > 0)) list(S_star = NA_real_, note = "above standard at every S")
  else if (all(d < 0)) list(S_star = NA_real_, note = "below standard at every S")
  else list(S_star = approx(d, S, xout = 0, ties = "ordered")$y, note = "")
}, by = series]

labels <- c(standard = "Standard design, best graph",
            protocol = "Group sequential, protocol design",
            graph = "Group sequential, best graph for each value",
            graph_gamma = "Group sequential, best graph and gamma for each value")
lines[, series := factor(labels[series], levels = labels)]
points[, series_label := factor(labels[series], levels = labels)]
break_even[, series_label := labels[series]]

fwrite(points, result_path("claim_value_points.csv"))
fwrite(break_even, result_path("claim_value_break_even.csv"))
cat(sprintf("Standard design: %.3f (protocol graph %.3f)\n", mean(std_val), mean(std_prot_val)))
print(points[, .(S, series, value = round(value, 2), se = round(se, 3),
                 vs_standard = sprintf("%+.2f (%.3f)", diff_vs_standard, se_diff), p_stop = round(p_stop, 3))],
      row.names = FALSE)
print(break_even[, .(series, S_star = round(S_star, 3), note)], row.names = FALSE)

## Chart (styled as the round-1 chart) -----------------------------------------
col <- c("#2a78d6", "#eb6834", "#9a9a9a", "#1baf7a")
names(col) <- labels
ink <- "#0b0b0b"; ink2 <- "#52514e"; grid_col <- "#e6e5e1"
base_theme <- theme_minimal(base_size = 13) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.4),
        axis.text = element_text(colour = ink2), axis.title = element_text(colour = ink2),
        plot.title = element_text(colour = ink, face = "bold"), plot.subtitle = element_text(colour = ink2),
        legend.position = "top", legend.justification = "left", legend.title = element_blank(),
        legend.text = element_text(colour = ink2), plot.title.position = "plot")
clear <- theme(plot.background = element_rect(fill = NA, colour = NA))

be_prot <- break_even[series == "protocol", S_star]
be_best <- break_even[series == "graph_gamma", S_star]
be_text <- sprintf("Protocol design overtakes\nstandard at S = %.2f", be_prot)
if (!is.na(be_best)) be_text <- paste0(be_text, sprintf("\n(best graph and gamma: S = %.2f)", be_best))
end_lab <- points[S == max(S)]

p <- ggplot(lines, aes(S, value, colour = series)) +
  geom_vline(xintercept = be_prot, colour = ink2, linewidth = 0.4, linetype = "dashed") +
  annotate("text", x = be_prot + 0.02, y = max(lines$value), hjust = 0, vjust = 1, colour = ink2, size = 3.6,
           label = be_text) +
  geom_line(aes(linetype = series), linewidth = 0.9) +
  geom_point(data = points, aes(S, value, colour = series_label), size = 2.6) +
  geom_text(data = end_lab, aes(S, value, label = sprintf("%.1f", value), colour = series_label),
            colour = ink, hjust = -0.35, size = 3.6, show.legend = FALSE, check_overlap = TRUE) +
  scale_colour_manual(values = col) +
  scale_linetype_manual(values = setNames(c("solid", "solid", "22", "solid"), labels)) +
  scale_x_continuous(breaks = S_opt, labels = paste0(S_opt, "x"), expand = expansion(mult = c(0.02, 0.09))) +
  labs(title = "What an early claim has to be worth",
       subtitle = "Expected value with highest-level claim values; 10% dropout a season;\nprotocol stopping rule (stop if NI ILI, SUP ILI 0% and NI SID are all rejected at season 1)",
       x = "Value of a claim made at season 1, relative to the same claim made at season 2 (S)",
       y = "Expected value") +
  guides(colour = guide_legend(ncol = 1), linetype = guide_legend(ncol = 1)) + base_theme
ggsave(result_path("fig_claim_value.png"), p, width = 8, height = 5.8, dpi = 200, bg = "white")
ggsave(result_path("fig_claim_value.pdf"), p + clear, width = 8, height = 5.8, bg = "transparent")
cat("figure written\n")
