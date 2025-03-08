# Load necessary libraries
library(shiny)
library(shinyjs)
library(shinythemes)
library(DT)
library(dplyr)
library(openxlsx)
library(stringr)
library(readr)     # For CSV
library(readxl)    # For Excel
library(jsonlite)  # For JSON
library(ggplot2)
library(plotly)    # For interactive plots

# 1. Define UI
ui <- fluidPage(
  theme = shinytheme("flatly"),  # Use a modern shiny theme
  useShinyjs(),                  # Enable shinyjs for extra interactivity
  titlePanel("Data Explorer & Comparison Tool"),
  navbarPage("",
             
             # 1.1 User Guide Part
             tabPanel("User Guide", fluidRow(
               column(12,
                      h3("Overview"),
                      p("This web application is designed to provide an interactive and user-friendly platform for data analysis, enabling users to seamlessly upload, clean, preprocess, engineer features, and explore datasets.. It provides an interactive and user-friendly platform for data analysis, allowing users to seamlessly upload, clean, preprocess, engineer features, and explore datasets. The app is designed to support data scientists and analysts by simplifying data handling and visualization."),
                      h4("Key Features:"),
                      tags$ul(
                        tags$li("Upload datasets in various formats (CSV, Excel, JSON, RDS) or use built-in sample datasets"),
                        tags$li("Interactive data cleaning: handling missing values, removing duplicates, and applying transformations"),
                        tags$li("Feature Engineering: Create new variables dynamically using custom expressions"),
                        tags$li("Exploratory Data Analysis (EDA): Generate interactive visualizations and statistical summaries"),
                        tags$li("Download cleaned/processed datasets for further analysis"),
                        tags$li("Responsive and user-friendly interface for smooth data exploration")
                      ),
                      h4("Navigation:"),
                      p("Use the tabs to navigate between Data Upload, Data Cleaning, Feature Engineering, EDA, and Download sections.")
               )
             )),
             
             # 1.2 Data Upload part
             tabPanel("Data Upload", sidebarLayout(
               sidebarPanel(
                 radioButtons("dataSource", "Data Source:",
                              choices = c("Upload File" = "upload", "Use Built-in Dataset" = "builtin"),
                              selected = "upload"),
                 conditionalPanel(
                   condition = "input.dataSource == 'upload'",
                   fileInput("file", "Choose a dataset",
                             accept = c(".csv", ".xlsx", ".json", ".rds"))
                 ),
                 conditionalPanel(
                   condition = "input.dataSource == 'builtin'",
                   selectInput("builtinDataset", "Select a dataset:",
                               choices = c("mtcars", "iris", "ToothGrowth"), selected = "mtcars")
                 ),
                 actionButton("loadData", "Load Data")
               ),
               mainPanel(
                 h4("Dataset Preview"),
                 DTOutput("dataPreview"),
                 h4("Dataset Structure"),
                 verbatimTextOutput("dataStructure")
               )
             )),
             
             # 1.3 Data Cleaning & Preprocessing Part
             tabPanel("Data Cleaning & Preprocessing", sidebarLayout(
               sidebarPanel(
                 h4("Cleaning Options"),
                 checkboxInput("removeDup", "Remove duplicate rows", value = TRUE),
                 radioButtons("missOpt", "Missing Value Handling:",
                              choices = c("Remove Rows" = "remove", "Impute with Mean/Mode" = "impute"),
                              selected = "remove"),
                 actionButton("clean", "Clean Data")
               ),
               mainPanel(DTOutput("cleanPreview"))
             )),
             
             # 1.4 Feature Engineering Part
             tabPanel("Feature Engineering", sidebarLayout(
               sidebarPanel(
                 h4("Create New Feature"),
                 textInput("newFeatureName", "New Feature Name:"),
                 textInput("newFeatureExpr", "Expression (use column names, e.g., mpg * wt):"),
                 actionButton("addFeature", "Add Feature")
               ),
               mainPanel(DTOutput("featurePreview"))
             )),
             
             # 1.5 Exploratory Data Analysis Part
             tabPanel("Exploratory Data Analysis", sidebarLayout(
               sidebarPanel(
                 h4("Select Plot Type"),
                 radioButtons("plotType", "Plot Type:",
                              choices = c("Histogram", "Boxplot", "Bar Chart", "Scatter Plot"),
                              selected = "Histogram"),
                 uiOutput("varSelectUI"),
                 actionButton("plotData", "Generate Plot")
               ),
               mainPanel(plotlyOutput("edaPlot"), verbatimTextOutput("summaryStats"))
             )),
             
             # 1.6 Download & Reset Part
             tabPanel("Download & Reset", fluidRow(
               column(6, downloadButton("downloadData", "Download Processed Data")),
               column(6, actionButton("reset", "Reset App"))
             ))
  )
)

# 2. Define Server logic
server <- function(input, output, session) {
  rv <- reactiveValues(data = NULL, cleaned = NULL)
  
  # 3. Load dataset based on user selection
  observeEvent(input$loadData, {
    if (input$dataSource == "upload") {
      req(input$file)
      ext <- tolower(tools::file_ext(input$file$name))
      rv$data <- switch(ext,
                        csv = read_csv(input$file$datapath),
                        xlsx = read_excel(input$file$datapath),
                        json = fromJSON(input$file$datapath, flatten = TRUE),
                        rds = readRDS(input$file$datapath),
                        { showNotification("File type not supported", type = "error"); return() }
      )
    } else {
      rv$data <- get(input$builtinDataset)
    }
  })
  
  # 4. Output the data preview and structure
  output$dataPreview <- renderDT({ req(rv$data); datatable(rv$data) })
  output$dataStructure <- renderPrint({ req(rv$data); str(rv$data) })
  
  # 5. Data Cleaning
  observeEvent(input$clean, {
    req(rv$data)
    data <- rv$data
    if (input$removeDup) data <- distinct(data)
    if (input$missOpt == "remove") data <- na.omit(data)
    else data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))
    rv$cleaned <- data
  })
  output$cleanPreview <- renderDT({ req(rv$cleaned); datatable(rv$cleaned) })
  
  # 6. Feature Engineering
  observeEvent(input$addFeature, {
    req(rv$cleaned, input$newFeatureName, input$newFeatureExpr)
    new_feature <- try(with(rv$cleaned, eval(parse(text = input$newFeatureExpr))), silent = TRUE)
    if (!inherits(new_feature, "try-error")) rv$cleaned[[input$newFeatureName]] <- new_feature
  })
  output$featurePreview <- renderDT({ req(rv$cleaned); datatable(rv$cleaned) })
}

# 7. Run the application
shinyApp(ui, server)
