need <- c("dplyr","readr","ggplot2","tidyr")
to_install <- setdiff(need, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, dependencies = TRUE)
library(dplyr); library(readr); library(ggplot2); library(tidyr)
df <- readr::read_csv("data/wdi_eu.csv", show_col_types = FALSE)
dir.create("results", showWarnings = FALSE)
# 1) Тренды по странам
plot_df <- df |>
  dplyr::filter(country %in% c("Austria","Germany","Slovak Republic","Poland")) |>
  tidyr::pivot_longer(c(gdp_pc, unemp, co2_pc), names_to = "metric", values_to = "value")
p1 <- ggplot(plot_df, aes(year, value, color = country)) +
  geom_line(na.rm = TRUE) +
  facet_wrap(~ metric, scales = "free_y") +
  labs(title = "WDI: GDP per capita / Unemployment / CO2 per capita", x = NULL, y = NULL)
ggsave("results/p1_trends.png", p1, width = 9, height = 5, dpi = 150)
# 2) Scatter (latest year)
latest <- df |>
  dplyr::group_by(country) |>
  dplyr::filter(year == max(year, na.rm = TRUE)) |>
  dplyr::ungroup()
if (!all(is.na(latest$co2_pc))) {
  p2 <- ggplot(latest, aes(gdp_pc, co2_pc, color = country)) +
    geom_point(size = 3, na.rm = TRUE) +
    labs(title = "Latest: CO2 per capita vs GDP per capita",
         x = "GDP per capita (constant $)", y = "CO2 per capita (tonnes/person)")
  ggsave("results/p2_scatter.png", p2, width = 7, height = 5, dpi = 150)
} else {
  message("Skip p2_scatter.png: CO2 per capita not available.")
}
