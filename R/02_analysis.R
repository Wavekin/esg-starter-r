need <- c("dplyr","readr")
to_install <- setdiff(need, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, dependencies = TRUE)
library(dplyr); library(readr)
df <- readr::read_csv("data/wdi_eu.csv", show_col_types = FALSE) |>
  dplyr::filter(!is.na(gdp_pc), !is.na(unemp))
m <- lm(unemp ~ gdp_pc + co2_pc, data = df)
cat("\n=== OLS: unemp ~ gdp_pc + co2_pc ===\n"); print(summary(m))
dir.create("results", showWarnings = FALSE)
capture.output(summary(m), file = "results/model_summary.txt")
latest <- df |>
  dplyr::group_by(country) |>
  dplyr::filter(year == max(year, na.rm = TRUE)) |>
  dplyr::ungroup() |>
  dplyr::arrange(country)
readr::write_csv(latest, "results/latest_by_country.csv")
cat("\nSaved: results/model_summary.txt, results/latest_by_country.csv\n")
