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
# No need to load haven/read_sas unless you plan to support SAS files

library(ggplot2)
library(plotly)    # For interactive plots

# Define UI
ui <- fluidPage(
  theme = shinytheme("flatly"),  # Use a modern shiny theme
  useShinyjs(),                  # Enable shinyjs for extra interactivity
  titlePanel("Data Explorer & Comparison Tool"),
  navbarPage("",
             tabPanel("User Guide",
                      fluidRow(
                        column(12,
                               h3("Overview"),
                               p("This web application allows users to upload datasets (CSV, Excel, JSON, or RDS), perform data cleaning, feature engineering, and explore the data interactively. The tool is designed to help streamline the data automation process in a statistical programming environment."),
                               h4("Key Features:"),
                               tags$ul(
                                 tags$li("Upload datasets in various formats or use built‐in sample datasets"),
                                 tags$li("Interactive data cleaning: missing value handling, duplicate removal, and basic transformations"),
                                 tags$li("Feature Engineering: Create new features using custom formulas"),
                                 tags$li("Exploratory Data Analysis (EDA): Interactive plots and summary statistics"),
                                 tags$li("Download cleaned/processed datasets")
                               ),
                               h4("Navigation:"),
                               p("Use the tabs to navigate between Data Upload, Data Cleaning, Feature Engineering, EDA, and Download sections.")
                        )
                      )
             ),
             tabPanel("Data Upload",
                      sidebarLayout(
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
                      )
             ),
             tabPanel("Data Cleaning & Preprocessing",
                      sidebarLayout(
                        sidebarPanel(
                          h4("Cleaning Options"),
                          checkboxInput("removeDup", "Remove duplicate rows", value = TRUE),
                          radioButtons("missOpt", "Missing Value Handling:",
                                       choices = c("Remove Rows" = "remove", "Impute with Mean/Mode" = "impute"),
                                       selected = "remove"),
                          actionButton("clean", "Clean Data")
                        ),
                        mainPanel(
                          h4("Cleaned Dataset Preview"),
                          DTOutput("cleanPreview")
                        )
                      )
             ),
             tabPanel("Feature Engineering",
                      sidebarLayout(
                        sidebarPanel(
                          h4("Create New Feature"),
                          textInput("newFeatureName", "New Feature Name:"),
                          textInput("newFeatureExpr", "Expression (use column names, e.g., mpg * wt):"),
                          actionButton("addFeature", "Add Feature")
                        ),
                        mainPanel(
                          h4("Dataset with New Feature"),
                          DTOutput("featurePreview")
                        )
                      )
             ),
             tabPanel("Exploratory Data Analysis",
                      sidebarLayout(
                        sidebarPanel(
                          h4("Select Plot Type"),
                          radioButtons("plotType", "Plot Type:",
                                       choices = c("Histogram", "Boxplot", "Bar Chart", "Scatter Plot"),
                                       selected = "Histogram"),
                          uiOutput("varSelectUI"),
                          actionButton("plotData", "Generate Plot")
                        ),
                        mainPanel(
                          h4("Plot"),
                          plotlyOutput("edaPlot"),
                          h4("Summary Statistics"),
                          verbatimTextOutput("summaryStats")
                        )
                      )
             ),
             tabPanel("Download & Reset",
                      fluidRow(
                        column(6, downloadButton("downloadData", "Download Processed Data")),
                        column(6, actionButton("reset", "Reset App"))
                      )
             )
  )
)

# Define Server logic
server <- function(input, output, session) {
  
  # Reactive value to hold the uploaded or built-in dataset
  rv <- reactiveValues(data = NULL, cleaned = NULL)
  
  # Load dataset based on user selection
  observeEvent(input$loadData, {
    if (input$dataSource == "upload") {
      req(input$file)
      ext <- tolower(tools::file_ext(input$file$name))
      # Read file based on extension
      if (ext == "csv") {
        rv$data <- read_csv(input$file$datapath)
      } else if (ext %in% c("xlsx", "xls")) {
        rv$data <- read_excel(input$file$datapath)
      } else if (ext == "json") {
        rv$data <- fromJSON(input$file$datapath, flatten = TRUE)
      } else if (ext == "rds") {
        rv$data <- readRDS(input$file$datapath)
      } else {
        showNotification("File type not supported", type = "error")
      }
    } else {
      # Load built-in dataset
      dataset <- input$builtinDataset
      rv$data <- get(dataset)
    }
  })
  
  # Output the data preview and structure
  output$dataPreview <- renderDT({
    req(rv$data)
    datatable(rv$data, options = list(scrollX = TRUE))
  })
  
  output$dataStructure <- renderPrint({
    req(rv$data)
    str(rv$data)
  })
  
  # Data cleaning: remove duplicates and handle missing values
  observeEvent(input$clean, {
    req(rv$data)
    data <- rv$data
    if (input$removeDup) {
      data <- distinct(data)
    }
    if (input$missOpt == "remove") {
      data <- na.omit(data)
    } else if (input$missOpt == "impute") {
      data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))
      data <- data %>% mutate(across(where(~ is.character(.)), ~ ifelse(is.na(.), Mode(.), .)))
    }
    rv$cleaned <- data
    showNotification("Data cleaned successfully", type = "message")
  })
  
  # Helper function for mode
  Mode <- function(x) {
    ux <- unique(x)
    ux[which.max(tabulate(match(x, ux)))]
  }
  
  # Preview cleaned data
  output$cleanPreview <- renderDT({
    req(rv$cleaned)
    datatable(rv$cleaned, options = list(scrollX = TRUE))
  })
  
  # Feature Engineering: add new feature based on expression
  observeEvent(input$addFeature, {
    req(rv$cleaned)
    req(input$newFeatureName, input$newFeatureExpr)
    # Evaluate the new feature expression in the context of the dataset
    new_feature <- try(with(rv$cleaned, eval(parse(text = input$newFeatureExpr))), silent = TRUE)
    if (inherits(new_feature, "try-error")) {
      showNotification("Error in expression. Please check your syntax.", type = "error")
    } else {
      rv$cleaned[[input$newFeatureName]] <- new_feature
      showNotification("New feature added.", type = "message")
    }
  })
  
  output$featurePreview <- renderDT({
    req(rv$cleaned)
    datatable(rv$cleaned, options = list(scrollX = TRUE))
  })
  
  # Dynamic UI for variable selection in EDA
  output$varSelectUI <- renderUI({
    req(rv$cleaned)
    if (input$plotType %in% c("Histogram", "Boxplot")) {
      selectInput("varSelect", "Select Variable:", choices = names(rv$cleaned))
    } else if (input$plotType == "Bar Chart") {
      selectInput("varSelect", "Select Categorical Variable:", 
                  choices = names(rv$cleaned)[sapply(rv$cleaned, function(x) is.character(x) || is.factor(x))])
    } else if (input$plotType == "Scatter Plot") {
      tagList(
        selectInput("xVar", "Select X Variable:", choices = names(rv$cleaned)),
        selectInput("yVar", "Select Y Variable:", choices = names(rv$cleaned))
      )
    }
  })
  
  # EDA Plot and summary
  observeEvent(input$plotData, {
    req(rv$cleaned)
    if (input$plotType %in% c("Histogram", "Boxplot", "Bar Chart")) {
      output$edaPlot <- renderPlotly({
        var <- input$varSelect
        req(var)
        p <- ggplot(rv$cleaned, aes_string(x = var))
        if (input$plotType == "Histogram") {
          p <- p + geom_histogram(fill = "steelblue", color = "white")
        } else if (input$plotType == "Boxplot") {
          p <- ggplot(rv$cleaned, aes_string(y = var)) + geom_boxplot(fill = "tomato")
        } else if (input$plotType == "Bar Chart") {
          p <- p + geom_bar(fill = "seagreen")
        }
        ggplotly(p)
      })
    } else if (input$plotType == "Scatter Plot") {
      output$edaPlot <- renderPlotly({
        req(input$xVar, input$yVar)
        p <- ggplot(rv$cleaned, aes_string(x = input$xVar, y = input$yVar)) +
          geom_point(color = "purple") +
          geom_smooth(method = "lm", se = FALSE, color = "black")
        ggplotly(p)
      })
    }
    
    output$summaryStats <- renderPrint({
      req(rv$cleaned)
      summary(rv$cleaned)
    })
  })
  
  # Download cleaned/processed data
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("processed_data_", Sys.Date(), ".xlsx", sep = "")
    },
    content = function(file) {
      req(rv$cleaned)
      write.xlsx(rv$cleaned, file)
    }
  )
  
  # Reset App Functionality: reload the session
  observeEvent(input$reset, {
    session$reload()
  })
}

# Run the application
shinyApp(ui, server)

