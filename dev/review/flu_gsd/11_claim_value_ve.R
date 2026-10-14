# Further analysis 3: how much an early claim has to be worth, across vaccine
# efficacy (VE). VE drives how many claims arrive at season 1, so it moves the
# break-even S at which the group sequential design overtakes the standard one.
#
# Designs (all fixed, tuned at the assumed VE of 25% ILI, 35% SID):
#   standard design (one analysis, best graph);
#   protocol design (protocol graph, protocol spending, protocol rule);
#   graph and shared gamma chosen inside multigrain for S = 1, 1.5, 2
#   (protocol rule; gamma -4, 0, 1).
# VE grid: ILI 15/25/35%, SID 20/35/50%, plus the round-1 assurance prior
# (ILI N(25%, 10%), SID N(35%, 15%), correlation 0.5; an illustrative prior).
# Per-claim timing, F = 1. Run from this folder: Rscript 11_claim_value_ve.R
source("00_setup.R"); source("design_library.R")

use <- c(protocol_design = "r2|protocol|protocol|protocol graph",
         grep("^r2\\|protocol\\|gamma .*\\|shared for S=", names(lib), value = TRUE))
names(use)[-1] <- sub(".*shared for ", "gamma design for ", use[-1])
designs <- lib[use]; names(designs) <- names(use)

draw_prior <- function(nsim, seed) {
  set.seed(seed)
  sd <- c(0.10, 0.15); R <- matrix(c(1, 0.5, 0.5, 1), 2)
  v <- mvtnorm::rmvnorm(nsim, c(0.25, 0.35), diag(sd) %*% R %*% diag(sd))
  v <- pmin(v, 0.99)   # a VE above 100% is not possible (affects a handful of draws)
  list(ILI = v[, 1], SID = v[, 2])
}
scen <- rbind(CJ(ve_ili = c(0.15, 0.25, 0.35), ve_sid = c(0.20, 0.35, 0.50))[, label := sprintf("ILI %d%%, SID %d%%", 100 * ve_ili, 100 * ve_sid)],
              data.table(ve_ili = NA_real_, ve_sid = NA_real_, label = "Assurance prior"))

S_grid <- seq(1, 4, by = 0.005)
res <- rbindlist(lapply(seq_len(nrow(scen)), function(i) {
  ve <- if (is.na(scen$ve_ili[i])) draw_prior(1e5, 2L) else c(ILI = scen$ve_ili[i], SID = scen$ve_sid[i])
  z <- simulate_z(1e5, test_seed, ve = ve)
  std <- trial_value(standard_times(z), "none")$value
  tms <- library_times(z, designs)
  # linear pieces: value(S) = S * E[L1] + E[(1 - stop)(L2 - L1)]
  coef <- rbindlist(lapply(names(designs), function(nm) {
    tm <- tms[[nm]]; R1 <- tm == 1L; colnames(R1) <- ids
    stop <- all_stop_rules[[designs[[nm]]$rule]](R1)
    L1 <- levels_value(R1); L2 <- levels_value(tm > 0L)
    v2 <- 2 * L1 + (1 - stop) * (L2 - L1)
    data.table(design = nm, slope = mean(L1), intercept = mean((1 - stop) * (L2 - L1)), p_stop = mean(stop),
               value_S1 = mean(L1 + (1 - stop) * (L2 - L1)), value_S2 = mean(v2),
               diff_S2_vs_std = mean(v2 - std), se_S2 = sd(v2 - std) / sqrt(length(std)))
  }))
  be <- function(slope, intercept) { s <- (mean(std) - intercept) / slope; if (s <= 1) 1 else s }
  best_curve <- sapply(S_grid, function(S) max(coef$slope * S + coef$intercept))
  be_best <- if (all(best_curve < mean(std))) NA_real_ else S_grid[which(best_curve >= mean(std))[1]]
  pick <- function(S) coef$design[which.max(coef$slope * S + coef$intercept)]
  data.table(label = scen$label[i], ve_ili = scen$ve_ili[i], ve_sid = scen$ve_sid[i], standard = mean(std),
             protocol_S1 = coef[design == "protocol_design", value_S1],
             protocol_S2 = coef[design == "protocol_design", value_S2],
             p_stop_protocol = coef[design == "protocol_design", p_stop],
             break_even_protocol = coef[design == "protocol_design", be(slope, intercept)],
             break_even_best = be_best,
             best_at_S1.5 = pick(1.5), best_at_S2 = pick(2),
             best_S2_vs_standard = sprintf("%+.2f (%.3f)", coef[design == pick(2), diff_S2_vs_std], coef[design == pick(2), se_S2]))
}))
fwrite(res, result_path("claim_value_ve.csv"))
print(res[, .(label, standard = round(standard, 2), protocol_S1 = round(protocol_S1, 2), protocol_S2 = round(protocol_S2, 2),
              p_stop = round(p_stop_protocol, 3), break_even_protocol = round(break_even_protocol, 2),
              break_even_best = round(break_even_best, 2), best_at_S1.5, best_at_S2)], row.names = FALSE)

## Chart: break-even S across the VE grid --------------------------------------------
ink <- "#0b0b0b"; ink2 <- "#52514e"
g <- melt(res[!is.na(ve_ili), .(ve_ili, ve_sid, `Protocol design` = break_even_protocol,
                                `Best graph and gamma` = break_even_best)],
          id.vars = c("ve_ili", "ve_sid"), variable.name = "design", value.name = "S_star")
g[, txt := ifelse(is.na(S_star), "never", ifelse(S_star <= 1.0001, "\u2264 1", sprintf("%.2f", S_star)))]
prior <- res[is.na(ve_ili)]
p <- ggplot(g, aes(factor(paste0(100 * ve_ili, "%")), factor(paste0(100 * ve_sid, "%")), fill = pmin(S_star, 1.4))) +
  geom_tile(colour = "white", linewidth = 1.2) +
  geom_text(aes(label = txt), colour = ink, size = 4.2) +
  facet_wrap(~ design) +
  scale_fill_gradient(low = "#e3f2ea", high = "#1b7a52", limits = c(1, 1.4), na.value = "#cfcfcf",
                      name = "Break-even S") +
  labs(title = "How much an early claim has to be worth, by vaccine efficacy",
       subtitle = sprintf("Break-even S against the standard design. Assurance prior: protocol design %.2f, best graph and gamma %.2f.\nDesigns tuned at ILI 25%%, SID 35%%; protocol stopping rule; per-claim timing.",
                          prior$break_even_protocol, prior$break_even_best),
       x = "Vaccine efficacy, ILI", y = "Vaccine efficacy, SID") +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA), panel.grid = element_blank(),
        plot.title = element_text(colour = ink, face = "bold"), plot.subtitle = element_text(colour = ink2),
        strip.text = element_text(face = "bold"), plot.title.position = "plot")
ggsave(result_path("fig_claim_value_ve.png"), p, width = 9, height = 4.8, dpi = 200, bg = "white")
ggsave(result_path("fig_claim_value_ve.pdf"), p + theme(plot.background = element_rect(fill = NA, colour = NA)),
       width = 9, height = 4.8, bg = "transparent")
cat("figure written\n")
