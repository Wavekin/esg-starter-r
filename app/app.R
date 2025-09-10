need <- c("shiny","bslib","dplyr","readr","ggplot2")
to_install <- setdiff(need, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, dependencies = TRUE)

library(shiny); library(bslib); library(dplyr); library(readr); library(ggplot2)

cands <- c("data/wdi_eu.csv", "../data/wdi_eu.csv", "../../data/wdi_eu.csv")
data_file <- cands[file.exists(cands)][1]
if (is.na(data_file)) stop("data/wdi_eu.csv not found. Запусти из корня: source('R/01_get_data.R')")
src_cands <- c("data/e_metric_source.txt", "../data/e_metric_source.txt", "../../data/e_metric_source.txt")
src_file  <- src_cands[file.exists(src_cands)][1]
e_source  <- if (!is.na(src_file)) readLines(src_file, warn = FALSE) else "E metric"

e_label <- dplyr::case_when(
  grepl("PM2.5", e_source) ~ "PM2.5 (µg/m³)",
  grepl("EN.ATM.CO2E.PC|computed CO2 per capita", e_source) ~ "CO₂ per capita (t/person)",
  grepl("Energy use", e_source) ~ "Energy use per capita (kg oe)",
  TRUE ~ "E metric"
)

df <- readr::read_csv(data_file, show_col_types = FALSE)

ui <- page_fillable(
  theme = bs_theme(bootswatch = "minty"),
  card(
    header = "ESG Starter (WDI proxies)",
    layout_columns(
      col_widths = c(4,8),
      card(
        h5("Filters"),
        selectizeInput("countries", "Countries",
          choices = sort(unique(df$country)),
          selected = c("Austria","Germany","Slovak Republic"),
          multiple = TRUE
        ),
        selectInput("metric", "Metric",
                    c("GDP per capita" = "gdp_pc",
                      "Unemployment (%)" = "unemp",
                      setNames("co2_pc", e_label))
        )
      ),
      card(
        h5("Time series"),
        plotOutput("ts_plot", height = 350),
        h5("Scatter (latest available year)"),
        plotOutput("sc_plot", height = 350)
      )
    )
  )
)
server <- function(input, output, session) {
  data_sel <- reactive({
    req(input$countries)
    df |> dplyr::filter(country %in% input$countries)
  })
  output$ts_plot <- renderPlot({
    ggplot(data_sel(), aes(year, .data[[input$metric]], color = country)) +
      geom_line(na.rm = TRUE) + labs(x = NULL, y = NULL)
  })
  output$sc_plot <- renderPlot({
    latest <- data_sel() |>
      dplyr::group_by(country) |>
      dplyr::arrange(dplyr::desc(year)) |>
      dplyr::filter(!is.na(co2_pc), !is.na(gdp_pc)) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup()
    
    validate(need(nrow(latest) > 0, "No non-missing data for scatter yet."))
    
    ggplot(latest, aes(gdp_pc, co2_pc, color = country)) +
      geom_point(size = 3) +
      labs(x = "GDP per capita (constant $)", y = e_label)
  })
  
}
shinyApp(ui, server)
