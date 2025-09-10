# R/01_get_data.R — robust fetch with multiple E-proxies
options(repos = c(CRAN = "https://cran.rstudio.com"))

need <- c("WDI","dplyr","readr")
to_install <- setdiff(need, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, dependencies = TRUE)

library(WDI)
library(dplyr)
library(readr)

countries  <- c("AT","DE","SK","CZ","PL","HU","RO","SI")
start_year <- 2000
end_year   <- 2024

# --- Base indicators (always) ---
message("Downloading GDP per capita + Unemployment ...")
base <- WDI(
  country   = countries,
  indicator = c(
    gdp_pc = "NY.GDP.PCAP.KD",
    unemp  = "SL.UEM.TOTL.ZS"
  ),
  start = start_year, end = end_year, extra = TRUE
) |>
  select(iso2c, country, year, gdp_pc, unemp)

if (!nrow(base)) stop("Base indicators did not download. Check WB API / internet.")

# --- Helper: try an indicator safely ---
try_indicator <- function(ind_code, rename_to = "value") {
  df <- tryCatch(
    WDI(country = countries, indicator = ind_code, start = start_year, end = end_year),
    error = function(e) data.frame()
  )
  # If empty or no such column, return NULL
  col_name <- ind_code
  if (!nrow(df) || !(ind_code %in% names(df))) return(NULL)
  # If all NA, return NULL
  if (all(is.na(df[[ind_code]]))) return(NULL)
  df |>
    transmute(iso2c, country, year, !!rename_to := .data[[ind_code]])
}

# --- Try E-metrics in order ---
used <- NULL
e_df <- NULL

# 1) Direct CO2 per capita
e_df <- try_indicator("EN.ATM.CO2E.PC", rename_to = "co2_pc")
if (!is.null(e_df)) used <- "EN.ATM.CO2E.PC (CO2 per capita)"

# 2) Construct from CO2 kt / population
if (is.null(e_df)) {
  kt  <- try_indicator("EN.ATM.CO2E.KT",  rename_to = "co2_kt")
  pop <- try_indicator("SP.POP.TOTL",     rename_to = "pop")
  if (!is.null(kt) && !is.null(pop)) {
    e_df <- kt |>
      left_join(pop, by = c("iso2c","country","year")) |>
      mutate(co2_pc = ifelse(is.na(co2_kt) | is.na(pop) | pop <= 0,
                             NA_real_, (co2_kt * 1000) / pop)) |>
      select(iso2c, country, year, co2_pc)
    if (!all(is.na(e_df$co2_pc))) used <- "EN.ATM.CO2E.KT/SP.POP.TOTL (computed CO2 per capita)"
    if (all(is.na(e_df$co2_pc))) e_df <- NULL
  }
}

# 3) PM2.5 (mcg/m3) as E-proxy
if (is.null(e_df)) {
  pm <- try_indicator("EN.ATM.PM25.MC.M3", rename_to = "co2_pc")
  if (!is.null(pm)) { e_df <- pm; used <- "EN.ATM.PM25.MC.M3 (PM2.5 as E-proxy)" }
}

# 4) Energy use per capita (kg of oil equivalent) as E-proxy
if (is.null(e_df)) {
  en <- try_indicator("EG.USE.PCAP.KG.OE", rename_to = "co2_pc")
  if (!is.null(en)) { e_df <- en; used <- "EG.USE.PCAP.KG.OE (Energy use as E-proxy)" }
}

if (is.null(e_df)) {
  warning("No E-metric available. Proceeding without co2_pc column.")
  out <- base |> arrange(country, year)
} else {
  message("E-metric used: ", used)
  out <- base |>
    left_join(e_df, by = c("iso2c","country","year")) |>
    arrange(country, year)
}

# --- Save ---
dir.create("data", showWarnings = FALSE, recursive = TRUE)
write_csv(out, "data/wdi_eu.csv")
message("Saved: data/wdi_eu.csv (", nrow(out), " rows, ", ncol(out), " cols).")

# Optional: store which metric was used
writeLines(used %||% "none", "data/e_metric_source.txt")

print(dplyr::glimpse(out))

