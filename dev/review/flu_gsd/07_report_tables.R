# Builds the LaTeX tables for the report from results/. Writes
# results/report_tables/*.tex. Run from this folder: Rscript 07_report_tables.R
source("00_setup.R")
out_dir <- result_path("report_tables"); dir.create(out_dir, showWarnings = FALSE)

f2 <- function(x) formatC(x, format = "f", digits = 2)
f3 <- function(x) formatC(x, format = "f", digits = 3)
fse <- function(x) ifelse(x < 0.005, "$<$0.01", f2(x))
pc <- function(x, d = 0) paste0(formatC(100 * x, format = "f", digits = d), "\\%")
sgn <- function(x, d = 2) ifelse(x >= 0, paste0("+", formatC(x, format = "f", digits = d)),
                                 paste0("$-$", formatC(abs(x), format = "f", digits = d)))
write_tab <- function(file, header, rows, align, midrules = integer()) {
  rows <- as.matrix(rows)
  header <- paste0("\\makecell[cb]{", header, "}")
  body <- paste(apply(rows, 1, paste, collapse = " & "), "\\\\")
  for (i in rev(midrules)) body <- append(body, "\\midrule", after = i)
  writeLines(c(sprintf("\\begin{tabular}{%s}", align), "\\toprule",
               paste(paste(header, collapse = " & "), "\\\\"), "\\midrule", body,
               "\\bottomrule", "\\end{tabular}"), file.path(out_dir, file))
}
hyp_lab <- c("NI ILI", "SUP ILI 0\\%", "NI SID", "SUP ILI 9.1\\%", "SUP SID 0\\%")
rule_lab <- c(none = "Continue regardless", protocol = "Protocol rule", alt = "Alternative rule")
sp_lab <- c(protocol = "OBF on SUP SID 0\\%", pocock = "Pocock, all five")

sc <- fread(result_path("scenarios.csv"))
sc[, rule := factor(rule, levels = names(rule_lab))]
sc[, spending := factor(spending, levels = names(sp_lab))]
setorder(sc, rule, spending, S, -graph)   # protocol row before optimised row

## Main scenario table: gain and differences
rows <- sc[, .(rule_lab[as.character(rule)], sp_lab[as.character(spending)], formatC(S, format = "g"),
               ifelse(graph == "protocol", "Protocol", "Optimised"),
               sprintf("%s (%s)", f2(gain), fse(se)), pc(p_stop),
               ifelse(graph == "protocol", "", sprintf("%s (%s)", sgn(diff_vs_protocol_graph), fse(se_graph))),
               sprintf("%s (%s)", sgn(diff_vs_protocol_design), fse(se_design)))]
rows[duplicated(rows[, 1:2]), 1:2] <- ""
write_tab("scenarios.tex", c("Stopping rule", "Spending", "$S$", "Graph", "Expected\\\\gain (SE)", "Stops at\\\\season 1",
                             "vs protocol\\\\graph (SE)", "vs protocol\\\\design (SE)"),
          rows, "llrlrrrr", midrules = seq(6, nrow(rows) - 1, by = 6))

## Power table
pw <- sc[, .(rule_lab[as.character(rule)], sp_lab[as.character(spending)], formatC(S, format = "g"),
             ifelse(graph == "protocol", "Protocol", "Optimised"),
             pc(pow_NI_ILI), pc(pow_SUP_ILI0), pc(pow_NI_SID), pc(pow_SUP_ILI91), pc(pow_SUP_SID0))]
pw[duplicated(pw[, 1:2]), 1:2] <- ""
write_tab("power.tex", c("Stopping rule", "Spending", "$S$", "Graph", hyp_lab), pw, "llrlrrrrr",
          midrules = seq(6, nrow(pw) - 1, by = 6))

## Headline at S = 2
g <- function(r, s, gr) sc[rule == r & spending == s & S == 2 & graph == gr]
gam <- fread(result_path("gamma__protocol__S2.00.csv"))
gbest <- gam[which.max(gain)]
gph <- fread(result_path("gamma_per_hyp__protocol__S2.00.csv")); gphb <- gph[which.max(gain)]
head_rows <- rbind(
  c("Protocol design (protocol graph, OBF on SUP SID 0\\%, protocol rule)", f2(g("protocol", "protocol", "protocol")$gain), "0", pc(g("protocol", "protocol", "protocol")$p_stop)),
  c("Protocol design, graph optimised", f2(g("protocol", "protocol", "optimised")$gain), sprintf("%s (%s)", sgn(g("protocol", "protocol", "optimised")$diff_vs_protocol_design), fse(g("protocol", "protocol", "optimised")$se_design)), pc(g("protocol", "protocol", "optimised")$p_stop)),
  c("Protocol rule, Pocock on SUP SID 0\\%, protocol graph", f2(g("protocol", "pocock", "protocol")$gain), sprintf("%s (%s)", sgn(g("protocol", "pocock", "protocol")$diff_vs_protocol_design), fse(g("protocol", "pocock", "protocol")$se_design)), pc(g("protocol", "pocock", "protocol")$p_stop)),
  c("Protocol rule, Pocock on SUP SID 0\\%, optimised graph", f2(g("protocol", "pocock", "optimised")$gain), sprintf("%s (%s)", sgn(g("protocol", "pocock", "optimised")$diff_vs_protocol_design), fse(g("protocol", "pocock", "optimised")$se_design)), pc(g("protocol", "pocock", "optimised")$p_stop)),
  c(sprintf("Protocol rule, optimised graph and shared $\\gamma = %g$", gbest$gamma), f2(gbest$gain), sprintf("%s (%s)", sgn(gbest$diff_vs_protocol_design), fse(gbest$se_design)), pc(gbest$p_stop)),
  c("Protocol rule, optimised graph and $\\gamma$ per hypothesis", f2(gphb$gain), sprintf("%s (%s)", sgn(gphb$diff_vs_protocol_design), fse(gphb$se_design)), pc(gphb$p_stop)),
  c("Continue regardless, protocol graph", f2(g("none", "protocol", "protocol")$gain), sprintf("%s (%s)", sgn(g("none", "protocol", "protocol")$diff_vs_protocol_design), fse(g("none", "protocol", "protocol")$se_design)), pc(0)),
  c("Alternative rule, OBF on SUP SID 0\\%, protocol graph", f2(g("alt", "protocol", "protocol")$gain), sprintf("%s (%s)", sgn(g("alt", "protocol", "protocol")$diff_vs_protocol_design), fse(g("alt", "protocol", "protocol")$se_design)), pc(g("alt", "protocol", "protocol")$p_stop)),
  c("Alternative rule, Pocock on SUP SID 0\\%, optimised graph", f2(g("alt", "pocock", "optimised")$gain), sprintf("%s (%s)", sgn(g("alt", "pocock", "optimised")$diff_vs_protocol_design), fse(g("alt", "pocock", "optimised")$se_design)), pc(g("alt", "pocock", "optimised")$p_stop))
)
write_tab("headline.tex", c("Design", "Expected\\\\gain", "vs protocol\\\\design (SE)", "Stops at\\\\season 1"), head_rows, "lrrr")

## Gamma table
gam <- gam[order(gamma)]
write_tab("gamma.tex", c("$\\gamma$", "Optimiser\\\\seeds", "Optimised\\\\graph (SE)", "Protocol\\\\graph", "Stops at\\\\season 1", "vs protocol\\\\design (SE)"),
          gam[, .(formatC(gamma, format = "g"), seeds, sprintf("%s (%s)", f2(gain), fse(se)), f2(gain_protocol_graph), pc(p_stop),
                  sprintf("%s (%s)", sgn(diff_vs_protocol_design), fse(se_design)))], "rrrrrr")

## Gamma per hypothesis
gph_rows <- gph[, c(list(step), lapply(.SD, function(x) formatC(x, format = "g")), list(sprintf("%s (%s)", f2(gain), fse(se)), pc(p_stop))),
                .SDcols = paste0("gamma_", ids)]
gph_rows[[1]] <- gsub("_", "\\\\_", gph_rows[[1]])
write_tab("gamma_per_hyp.tex", c("Step", hyp_lab, "Optimised\\\\graph (SE)", "Stops at\\\\season 1"), gph_rows, "lrrrrrrr")

## Optimised graphs (longtable; edges below 0.01 dropped for readability)
gr <- fread(result_path("graphs.csv"))
gr[, rule := factor(rule, levels = names(rule_lab))]; gr[, spending := factor(spending, levels = names(sp_lab))]
setorder(gr, rule, spending, S)
trim_edges <- function(e) {
  parts <- strsplit(e, "; ")[[1]]
  w <- as.numeric(sub(".* ", "", parts))
  parts <- parts[w >= 0.01]
  paste(gsub("_", "\\\\_", gsub(" -> ", " $\\\\to$ ", parts)), collapse = "; ")
}
grows <- gr[, .(rule_lab[as.character(rule)], sp_lab[as.character(spending)], formatC(S, format = "g"), sapply(edges, trim_edges))]
grows[duplicated(grows[, 1:2]), 1:2] <- ""
body <- paste(apply(as.matrix(grows), 1, paste, collapse = " & "), "\\\\")
for (i in rev(seq(3, nrow(grows) - 1, by = 3))) body <- append(body, "\\midrule", after = i)
writeLines(c("\\begin{longtable}{llrp{8.6cm}}",
             "\\toprule", "Stopping rule & Spending & $S$ & Edges (initial $\\alpha$ all on NI ILI; weights below 0.01 dropped) \\\\ \\midrule", "\\endhead",
             "\\bottomrule", "\\endfoot", body, "\\end{longtable}"), file.path(out_dir, "graphs.tex"))

## Participants
pt <- fread(result_path("participants.csv"))
write_tab("participants.tex", c("Design to match", "Its expected\\\\gain", "Protocol design\\\\needs, per arm", "Extra\\\\per arm"),
          pt[, .(design, f2(target_gain), format(n_match, big.mark = ","), format(extra_per_arm, big.mark = ","))], "lrrr")

## Numbers used inline
num <- c(stop_cost = sc[rule == "none" & graph == "protocol" & S == 1, diff_vs_protocol_design],
         p_stop_protocol = sc[rule == "protocol" & spending == "protocol" & graph == "protocol" & S == 2, p_stop],
         p_stop_alt = sc[rule == "alt" & spending == "protocol" & graph == "protocol" & S == 2, p_stop])
writeLines(sprintf("\\newcommand{\\%s}{%s}", c("stopcost", "pstopprotocol", "pstopalt"),
                   c(f2(num[["stop_cost"]]), pc(num[["p_stop_protocol"]]), pc(num[["p_stop_alt"]]))),
           file.path(out_dir, "numbers.tex"))
cat("Written to", out_dir, "\n")

## Gamma inside the package (03c)
gp_file <- result_path("gamma_in_package.csv")
if (file.exists(gp_file)) {
  gp <- fread(gp_file)
  gp[, rule := factor(rule, levels = names(rule_lab))]
  setorder(gp, rule, S, -mode)   # shared before per hypothesis
  gam_cols <- paste0("gamma_", ids)
  gl <- function(r) {
    g <- as.numeric(r[, gam_cols, with = FALSE])
    if (length(unique(g)) == 1L) formatC(g[1], format = "g") else paste(formatC(g, format = "g"), collapse = ", ")
  }
  rows <- gp[, .(rule_lab[as.character(rule)], formatC(S, format = "g"), mode,
                 sapply(seq_len(.N), function(i) gl(.SD[i])),
                 sprintf("%s (%s)", f2(gain), fse(se)), pc(p_stop),
                 f2(gain_opt_graph_protocol_spending),
                 sprintf("%s (%s)", sgn(diff_vs_protocol_design), fse(se_design)),
                 sgn(diff_vs_opt_graph_protocol_spending))]
  rows[duplicated(rows[, 1]), 1] <- ""
  write_tab("gamma_in_package.tex",
            c("Stopping rule", "$S$", "$\\gamma$", "Chosen $\\gamma$\\\\(NI ILI, SUP ILI 0\\%, NI SID,\\\\SUP ILI 9.1\\%, SUP SID 0\\%)",
              "Optimised graph\\\\and $\\gamma$ (SE)", "Stops at\\\\season 1", "Optimised graph,\\\\protocol spending",
              "vs protocol\\\\design (SE)", "vs optimised graph,\\\\protocol spending"),
            rows, "lrlcrrrrr", midrules = seq(6, nrow(rows) - 1, by = 6))
}
