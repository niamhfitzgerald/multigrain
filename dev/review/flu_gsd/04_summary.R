# Summary table across all scenarios, and the two figures (S sensitivity and
# the gamma optimisation). Reads results/scenarios.csv and results/gamma__*.csv.
# Run from this folder: Rscript 04_summary.R
source("00_setup.R")

sc <- fread(result_path("scenarios.csv"))
rule_labels <- c(none = "Continue regardless", protocol = "Protocol rule", alt = "Alternative rule")
spend_labels <- c(protocol = "OBF on SUP_SID0", pocock = "Pocock for all")
sc[, rule_label := factor(rule_labels[rule], levels = rule_labels)]
sc[, spend_label := factor(spend_labels[spending], levels = spend_labels)]
sc[, graph_label := factor(ifelse(graph == "protocol", "Protocol graph", "Optimised graph"),
                           levels = c("Protocol graph", "Optimised graph"))]

## Summary table ---------------------------------------------------------------
pm <- function(x, se, d = 2) sprintf("%s (%s)", fmt(x, d), fmt(se, 3))
tab <- sc[order(rule_label, spend_label, S, graph_label), .(
  Scenario = as.character(rule_label), Spending = as.character(spend_label), S, Graph = as.character(graph_label),
  `Expected gain (SE)` = pm(gain, se),
  `P(stop at interim)` = fmt(p_stop, 3),
  NI_ILI = fmt(pow_NI_ILI, 3), SUP_ILI0 = fmt(pow_SUP_ILI0, 3), NI_SID = fmt(pow_NI_SID, 3),
  SUP_ILI91 = fmt(pow_SUP_ILI91, 3), SUP_SID0 = fmt(pow_SUP_SID0, 3),
  `vs protocol graph (SE)` = ifelse(graph == "protocol", "", pm(diff_vs_protocol_graph, se_graph)),
  `vs protocol design (SE)` = pm(diff_vs_protocol_design, se_design))]
fwrite(tab, result_path("summary_table.csv"))
md_table <- function(d) {
  d <- as.data.frame(d); d[] <- lapply(d, as.character)
  paste(c(paste0("| ", paste(names(d), collapse = " | "), " |"),
          paste0("|", paste(rep("---", ncol(d)), collapse = "|"), "|"),
          apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))), collapse = "\n")
}
writeLines(md_table(tab), result_path("summary_table.md"))

## Gamma results (if present) ------------------------------------------------------------
gf <- list.files(result_path(), "^gamma__.*\\.csv$", full.names = TRUE)
gam <- if (length(gf)) rbindlist(lapply(gf, fread), fill = TRUE) else NULL
if (!is.null(gam)) {
  gtab <- gam[order(rule, S, gamma), .(Scenario = rule_labels[rule], S, gamma, Seeds = seeds,
    `Optimised graph (SE)` = pm(gain, se), `Protocol graph` = fmt(gain_protocol_graph),
    `P(stop)` = fmt(p_stop, 3), `vs protocol design (SE)` = pm(diff_vs_protocol_design, se_design))]
  fwrite(gtab, result_path("gamma_table.csv"))
  writeLines(md_table(gtab), result_path("gamma_table.md"))
}

## Figures ---------------------------------------------------------------------------------
okabe <- c("Protocol graph" = "#0072B2", "Optimised graph" = "#D55E00")
theme_flu <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom",
        strip.text = element_text(face = "bold"))

# Figure 1: expected gain against S, by stopping rule and spending.
fig_s <- ggplot(sc, aes(S, gain, colour = graph_label, linetype = spend_label, shape = spend_label)) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.4, fill = "white") +
  facet_wrap(~ rule_label) +
  scale_colour_manual(values = okabe, name = NULL) +
  scale_linetype_manual(values = c("solid", "22"), name = NULL) +
  scale_shape_manual(values = c(16, 21), name = NULL) +
  scale_x_continuous(breaks = c(1, 1.5, 2)) +
  labs(x = "S: value of a claim at the interim, relative to a claim at the end of season 2",
       y = "Expected gain (highest-level values, max 35 at S = 1)",
       title = "Expected gain against the value of an early claim",
       subtitle = "100,000 test trials; Monte Carlo SE about 0.03 to 0.05") +
  theme_flu
ggsave(result_path("fig_S_sensitivity.pdf"), fig_s, width = 9, height = 4.2)
ggsave(result_path("fig_S_sensitivity.png"), fig_s, width = 9, height = 4.2, dpi = 200)

# Figure 2: gain difference from the protocol design against S (the quantity that
# decides the design), same layout.
fig_s2 <- ggplot(sc, aes(S, diff_vs_protocol_design, colour = graph_label, linetype = spend_label, shape = spend_label)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.7) +
  geom_point(size = 2.4, fill = "white") +
  facet_wrap(~ rule_label) +
  scale_colour_manual(values = okabe, name = NULL) +
  scale_linetype_manual(values = c("solid", "22"), name = NULL) +
  scale_shape_manual(values = c(16, 21), name = NULL) +
  scale_x_continuous(breaks = c(1, 1.5, 2)) +
  labs(x = "S: value of a claim at the interim, relative to a claim at the end of season 2",
       y = "Gain minus protocol design (same S)",
       title = "Gain over the protocol design against the value of an early claim",
       subtitle = "Protocol design: protocol graph, OBF on SUP_SID0, protocol stopping rule") +
  theme_flu
ggsave(result_path("fig_S_vs_protocol_design.pdf"), fig_s2, width = 9, height = 4.2)
ggsave(result_path("fig_S_vs_protocol_design.png"), fig_s2, width = 9, height = 4.2, dpi = 200)

# Figure 3: gamma optimisation
if (!is.null(gam)) {
  gl <- melt(gam[, .(rule, S, gamma, `Optimised graph` = gain, `Protocol graph` = gain_protocol_graph)],
             id.vars = c("rule", "S", "gamma"), variable.name = "graph_label", value.name = "gain")
  gl[, rule_label := factor(rule_labels[rule], levels = rule_labels)]
  ref <- unique(gam[, .(rule, S, protocol_design = gain - diff_vs_protocol_design)])
  ref[, rule_label := factor(rule_labels[rule], levels = rule_labels)]
  ref <- ref[, .(protocol_design = mean(protocol_design)), by = .(rule_label, S)]
  fig_g <- ggplot(gl, aes(gamma, gain, colour = graph_label)) +
    geom_hline(data = ref, aes(yintercept = protocol_design), colour = "grey50", linetype = "22") +
    geom_vline(xintercept = c(-4, 1), colour = "grey80") +
    geom_line(linewidth = 0.7) +
    geom_point(size = 2.2) +
    facet_grid(S ~ rule_label, labeller = labeller(S = function(x) paste0("S = ", x))) +
    scale_colour_manual(values = okabe, name = NULL) +
    scale_x_continuous(breaks = -4:1) +
    labs(x = "Hwang-Shih-DeCani gamma, shared by all hypotheses (-4 near O'Brien-Fleming, 1 near Pocock)",
         y = "Expected gain", title = "Expected gain against the spending parameter",
         subtitle = "Dashed grey: protocol design (protocol graph, OBF on SUP_SID0, protocol rule)") +
    theme_flu
  ggsave(result_path("fig_gamma.pdf"), fig_g, width = 8, height = 4.2)
  ggsave(result_path("fig_gamma.png"), fig_g, width = 8, height = 4.2, dpi = 200)
}
cat("Written:", paste(list.files(result_path(), "summary|gamma_table|fig_"), collapse = ", "), "\n")

## Figure 4: gamma inside the package, against S
gp_file <- result_path("gamma_in_package.csv")
if (file.exists(gp_file)) {
  gp <- fread(gp_file)
  base <- sc[graph == "protocol" & spending == "protocol" & rule == "protocol", .(S, protocol_design = gain)]
  ogps <- sc[graph == "optimised" & spending == "protocol", .(rule, S, `Optimised graph, protocol spending` = gain)]
  wide <- dcast(gp[, .(rule, S, mode = ifelse(mode == "shared", "Optimised graph, shared gamma", "Optimised graph, gamma per hypothesis"), gain)],
                rule + S ~ mode, value.var = "gain")
  wide <- merge(wide, ogps, by = c("rule", "S"))
  wide <- merge(wide, base, by = "S")
  setnames(wide, "protocol_design", "Protocol design")
  long <- melt(wide, id.vars = c("rule", "S"), variable.name = "design", value.name = "gain")
  long <- merge(long, base[, .(S, pd = protocol_design)], by = "S")
  long[, gain := gain - pd]
  long[, rule_label := factor(rule_labels[rule], levels = rule_labels)]
  long[, design := factor(design, levels = c("Protocol design", "Optimised graph, protocol spending",
                                             "Optimised graph, shared gamma", "Optimised graph, gamma per hypothesis"))]
  pal <- c("Protocol design" = "#7f7f7f", "Optimised graph, protocol spending" = "#0072B2",
           "Optimised graph, shared gamma" = "#D55E00", "Optimised graph, gamma per hypothesis" = "#009E73")
  fig_gp <- ggplot(long, aes(S, gain, colour = design, shape = design)) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_line(linewidth = 0.7) + geom_point(size = 2.4) +
    facet_wrap(~ rule_label) +
    scale_colour_manual(values = pal, name = NULL) +
    scale_shape_manual(values = c(16, 17, 15, 18), name = NULL) +
    scale_x_continuous(breaks = c(1, 1.5, 2)) +
    guides(colour = guide_legend(nrow = 2)) +
    labs(x = "S: value of a claim at the interim, relative to a claim at the end of season 2",
         y = "Gain minus protocol design (same S)",
         title = "Gamma optimised inside multigrain, against the value of an early claim",
         subtitle = "Candidates gamma = -4, -3, -2, -1, 0, 0.5, 1; graph and gamma chosen jointly by graph_optimise_gsd()") +
    theme_flu
  ggsave(result_path("fig_gamma_in_package.pdf"), fig_gp, width = 9, height = 4.4)
  ggsave(result_path("fig_gamma_in_package.png"), fig_gp, width = 9, height = 4.4, dpi = 200)
}
