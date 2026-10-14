# Further analysis 2: a bonus for finishing early (round 1) and a bonus for
# each early claim (round 2), together.
#
#   F: a trial that stops at season 1 has its whole value multiplied by F
#      (round 1 used F = 2 with S = 1).
#   S: each claim made at season 1 is worth S times the same claim made at
#      season 2 (round 2 used S = 1, 1.5, 2 with F = 1).
#
# For a fixed design, with L1 and L2 the levels reached by season 1 and 2,
#   value(S, F) = F S E[stop L1] + (S - 1) E[(1 - stop) L1] + E[(1 - stop) L2],
# so three averages per design give its value everywhere on the (S, F) plane.
# The map shows which design in the library (both rounds, 59 designs plus the
# standard design) is best at each point. Designs were tuned at only a few
# points, so the map is a lower bound on what re-optimising would give.
# Run from this folder: Rscript 10_finish_claim_map.R
source("00_setup.R"); source("design_library.R")

z_test <- simulate_z(1e5, test_seed)
tms <- library_times(z_test)
std_tm <- standard_times(z_test)

pieces_of <- function(tm, rule) {
  R1 <- tm == 1L; colnames(R1) <- ids
  stop <- all_stop_rules[[rule]](R1)
  L1 <- levels_value(R1); L2 <- levels_value(tm > 0L)
  list(a = stop * L1, b = (1 - stop) * L1, c = (1 - stop) * L2, stop = stop)
}
# Every graph and spending set in the library, under every stopping rule
xd <- cross_designs()
tm_of <- function(nm) if (nm == "standard") std_tm else tms[[xd[[nm]]$base]]
rule_of <- function(nm) if (nm == "standard") "none" else xd[[nm]]$rule
coef <- rbindlist(lapply(c(names(xd), "standard"), function(nm) {
  p <- pieces_of(tm_of(nm), rule_of(nm))
  data.table(design = nm, a = mean(p$a), b = mean(p$b), c = mean(p$c), p_stop = mean(p$stop))
}))
meta <- rbind(rbindlist(lapply(xd, function(d) data.table(design = d$name, base = d$base, round = d$round, rule = d$rule,
                                                         base_rule = d$base_rule, spend_key = d$spend_key, tuned_for = d$tuned_for))),
              data.table(design = "standard", base = "standard", round = 0, rule = "standard", base_rule = "standard",
                         spend_key = "-", tuned_for = ""))
coef <- merge(coef, meta, by = "design")
akeys <- unique(coef$spend_key[coef$spend_key != "-"])
ashare <- setNames(vapply(akeys, alpha_share_interim, 1), akeys)
coef[, alpha_share := ifelse(spend_key == "-", 0, ashare[spend_key])]
fwrite(coef, result_path("finish_claim_coefficients.csv"))

grid <- CJ(S = seq(1, 2.5, by = 0.025), F = seq(1, 2.5, by = 0.025))
vals <- outer(grid$S * grid$F, coef$a) + outer(grid$S - 1, coef$b) + matrix(coef$c, nrow(grid), nrow(coef), byrow = TRUE)
colnames(vals) <- coef$design
win <- max.col(vals, ties.method = "first")
prot <- vals[, "r2|protocol|protocol|protocol graph || rule=protocol"]
grid[, `:=`(best_design = coef$design[win], best_value = vals[cbind(seq_len(.N), win)],
            rule = coef$rule[win], spend_key = coef$spend_key[win], alpha_share = coef$alpha_share[win],
            p_stop = coef$p_stop[win], protocol_design = prot, standard = vals[, "standard"])]
grid[, gain_vs_protocol_design := best_value - protocol_design]
fwrite(grid, result_path("finish_claim_map.csv"))

# Points of interest, with the paired SE of the gain over the protocol design
poi <- data.table(label = c("No bonus", "Round 1 (finish x2)", "Round 2 (claims x1.5)", "Round 2 (claims x2)", "Both x1.5", "Both x2"),
                  S = c(1, 1, 1.5, 2, 1.5, 2), F = c(1, 2, 1, 1, 1.5, 2))
pv <- function(nm, S, F) { p <- pieces_of(tm_of(nm), rule_of(nm)); F * S * p$a + (S - 1) * p$b + p$c }
poi_tab <- rbindlist(lapply(seq_len(nrow(poi)), function(i) {
  g <- grid[abs(S - poi$S[i]) < 1e-9 & abs(F - poi$F[i]) < 1e-9]
  d <- pv(g$best_design, poi$S[i], poi$F[i]) - pv("r2|protocol|protocol|protocol graph || rule=protocol", poi$S[i], poi$F[i])
  data.table(point = poi$label[i], S = poi$S[i], F = poi$F[i], best_design = g$best_design, base = coef[design == g$best_design, base], rule = rule_names[g$rule],
             spend_key = g$spend_key, alpha_share = round(g$alpha_share, 2), p_stop = round(g$p_stop, 3),
             best_value = round(g$best_value, 2), protocol_design = round(g$protocol_design, 2),
             standard = round(g$standard, 2), gain_vs_protocol_design = sprintf("%+.2f (%.3f)", mean(d), sd(d) / sqrt(length(d))))
}))
fwrite(poi_tab, result_path("finish_claim_points.csv"))
print(poi_tab, row.names = FALSE)
cat("\nShare of the plane won by each stopping rule:\n")
print(grid[, .(share = round(.N / nrow(grid), 3)), by = rule][order(-share)], row.names = FALSE)

## Charts --------------------------------------------------------------------------
ink <- "#0b0b0b"; ink2 <- "#52514e"
rule_cols <- c(standard = "#7f7f7f", none = "#2a78d6", protocol = "#1baf7a", alt = "#eb6834",
               r1 = "#a35bd6", primary_only = "#d6a12a", sup_ili_only = "#c43c6a", plus_ni_sid = "#4cb5c4",
               both_sup = "#8c6d3a")
present <- intersect(names(rule_cols), unique(grid$rule))
grid[, rule_label := factor(rule_names[rule], levels = rule_names[present])]
pts <- copy(poi)
theme_map <- theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), panel.grid = element_blank(),
        plot.title = element_text(colour = ink, face = "bold"), plot.subtitle = element_text(colour = ink2),
        axis.text = element_text(colour = ink2), axis.title = element_text(colour = ink2),
        legend.position = "right", plot.title.position = "plot")
xlab <- "S: value of a claim made at season 1, relative to season 2"
ylab <- "F: bonus on a trial that stops at season 1"
mark <- list(geom_point(data = pts, aes(S, F), inherit.aes = FALSE, shape = 21, fill = "white", colour = ink, size = 2.6),
             geom_text(data = pts, aes(S, F, label = label), inherit.aes = FALSE, colour = ink, size = 3,
                       hjust = -0.12, vjust = -0.6))

m1 <- ggplot(grid, aes(S, F, fill = rule_label)) + geom_raster() +
  scale_fill_manual(values = setNames(rule_cols[present], rule_names[present]), name = "Stopping rule of the\nbest design") +
  mark + coord_equal(expand = FALSE) +
  labs(title = "Which stopping rule wins depends on how an early result is valued",
       subtitle = "Best of 59 graph-and-spending designs from both rounds, each under 8 stopping rules,\nplus the standard design; highest-level claim values",
       x = xlab, y = ylab) + theme_map
ggsave(result_path("fig_finish_claim_rule.png"), m1, width = 9, height = 6.4, dpi = 200, bg = "white")
ggsave(result_path("fig_finish_claim_rule.pdf"), m1 + theme(plot.background = element_rect(fill = NA, colour = NA)),
       width = 9, height = 6.4, bg = "transparent")

grid[, gain_band := cut(gain_vs_protocol_design, breaks = c(-Inf, 0.5, 1, 2, 4, 8, 16, Inf),
                         labels = c("under 0.5", "0.5 to 1", "1 to 2", "2 to 4", "4 to 8", "8 to 16", "16 or more"))]
band_cols <- c("#eef3fb", "#d3e0f3", "#b0c7ea", "#85a8dc", "#5786cb", "#2f63ae", "#163f7a")
pts_gain <- merge(pts, grid[, .(S = round(S, 3), F = round(F, 3), gain_vs_protocol_design)][, `:=`(S = S, F = F)],
                  by.x = c("S", "F"), by.y = c("S", "F"))
m2 <- ggplot(grid, aes(S, F)) + geom_raster(aes(fill = gain_band)) +
  scale_fill_manual(values = band_cols, drop = FALSE, name = "Gain of the best\ndesign over the\nprotocol design") +
  geom_point(data = pts_gain, aes(S, F), inherit.aes = FALSE, shape = 21, fill = "white", colour = ink, size = 2.6) +
  geom_label(data = pts_gain, aes(S, F, label = sprintf("%s: +%.1f", label, gain_vs_protocol_design)), inherit.aes = FALSE,
             colour = ink, size = 3, hjust = -0.06, vjust = -0.35, label.size = 0, fill = "white", alpha = 0.85) +
  coord_equal(expand = FALSE) +
  labs(title = "How much a better design is worth, against the protocol design",
       subtitle = "Same designs as the stopping-rule map; highest-level claim values",
       x = xlab, y = ylab) + theme_map
ggsave(result_path("fig_finish_claim_gain.png"), m2, width = 9, height = 6.4, dpi = 200, bg = "white")
ggsave(result_path("fig_finish_claim_gain.pdf"), m2 + theme(plot.background = element_rect(fill = NA, colour = NA)),
       width = 9, height = 6.4, bg = "transparent")
cat(sprintf("Share of the plane where the best design spends the most alpha the gamma range allows (%.0f%%): %.2f\n",
            100 * max(grid$alpha_share), mean(abs(grid$alpha_share - max(grid$alpha_share)) < 1e-6)))
cat("figures written\n")
