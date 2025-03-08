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
                      p("This web application is designed to provide an interactive and user-friendly platform for data analysis, enabling users to seamlessly upload, clean, preprocess, engineer features, and explore datasets. The app simplifies data handling and visualization for data scientists and analysts."),
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
             ))
             ,
             
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
                 
                 # 1.3.1 Choose whether to remove duplicate values
                 checkboxInput("removeDup", "Remove duplicate rows", value = TRUE),
                 
                 # 1.3.2 Options for handling missing values
                 checkboxInput("handleMissing", "Handle Missing Values", value = FALSE),  # Checkbox
                 conditionalPanel(
                   condition = "input.handleMissing == true",  # Display only when checked
                   radioButtons("missOpt", label = NULL,
                                choices = c("Remove Rows" = "remove", 
                                            "Impute with Mean" = "mean",
                                            "Impute with Median" = "median",
                                            "Impute with Mode" = "mode"),
                                selected = "remove")
                 ),
                 
                 # 1.3.3 Handle outliers
                 checkboxInput("handleOutliers", "Handle Outliers", value = FALSE),
                 conditionalPanel(
                   condition = "input.handleOutliers == true",
                   radioButtons("outlierMethod", label = NULL,
                                choices = c("Z-score" = "zscore", "IQR" = "iqr"),
                                selected = "zscore")
                 ),
                 
                 # 1.3.4 Normalize numerical data
                 checkboxInput("normalizeData", "Normalize Numerical Features", value = FALSE),
                 
                 # 1.3.5 Encode categorical variables (One-Hot Encoding or Label Encoding)
                 checkboxInput("encodeCategorical", "Encode Categorical Variables", value = FALSE),
                 
                 # 1.3.6 Clean data button
                 actionButton("clean", "Clean Data")
               ),
               
               mainPanel(
                 h4("Preview: Before & After Cleaning"),
                 tabsetPanel(
                   tabPanel("Before Cleaning", DTOutput("beforeCleanPreview")),
                   tabPanel("After Cleaning", DTOutput("cleanPreview"))
                 )
               )
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
  
  # 2.1 Data Load Server
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
  
  output$dataPreview <- renderDT({ req(rv$data); datatable(rv$data) })
  output$dataStructure <- renderPrint({ req(rv$data); str(rv$data) })
  
  # 2.3 Data Cleaning & Preprocessing Server
  observeEvent(input$clean, {
    req(rv$data)
    data <- rv$data
    
    # Remove duplicate values
    if (input$removeDup) {
      data <- distinct(data)
    }
    
    # Handle missing values
    if (input$handleMissing) {
      if (input$missOpt == "remove") {
        data <- na.omit(data)
      } else if (input$missOpt == "mean") {
        data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))
      } else if (input$missOpt == "median") {
        data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), median(., na.rm = TRUE), .)))
      } else if (input$missOpt == "mode") {
        Mode <- function(x) { ux <- unique(x); ux[which.max(tabulate(match(x, ux)))] }
        data <- data %>% mutate(across(where(is.character), ~ ifelse(is.na(.), Mode(.), .)))
      }
    }
    
    # Handle outliers
    if (input$handleOutliers) {
      if (input$outlierMethod == "zscore") {
        zscore_outliers <- function(x) {
          z_scores <- (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
          x[abs(z_scores) > 3] <- NA
          return(x)
        }
        data <- data %>% mutate(across(where(is.numeric), zscore_outliers))
      } else if (input$outlierMethod == "iqr") {
        iqr_outliers <- function(x) {
          Q1 <- quantile(x, 0.25, na.rm = TRUE)
          Q3 <- quantile(x, 0.75, na.rm = TRUE)
          IQR_value <- Q3 - Q1
          x[x < (Q1 - 1.5 * IQR_value) | x > (Q3 + 1.5 * IQR_value)] <- NA
          return(x)
        }
        data <- data %>% mutate(across(where(is.numeric), iqr_outliers))
      }
    }
    
    # Normalize numerical data
    if (input$normalizeData) {
      data <- data %>% mutate(across(where(is.numeric), ~ ( . - min(. ,na.rm = TRUE)) / (max(.) - min(.))))
    }
    
    # Encode categorical variables (One-Hot Encoding or Label Encoding)
    if (input$encodeCategorical) {
      data <- data %>% mutate(across(where(is.character), as.factor))
    }
    
    # Save cleaned data
    rv$cleaned <- data
    
    # Send notification
    showNotification("Data cleaned successfully", type = "message")
  })
  
  # Display data before and after cleaning
  output$beforeCleanPreview <- renderDT({ req(rv$data); datatable(rv$data, options = list(scrollX = TRUE)) })
  output$cleanPreview <- renderDT({ req(rv$cleaned); datatable(rv$cleaned, options = list(scrollX = TRUE)) })
  
  # 2.4 Feature Engineering Server
  observeEvent(input$addFeature, {
    req(rv$cleaned, input$newFeatureName, input$newFeatureExpr)
    new_feature <- try(with(rv$cleaned, eval(parse(text = input$newFeatureExpr))), silent = TRUE)
    if (!inherits(new_feature, "try-error")) rv$cleaned[[input$newFeatureName]] <- new_feature
  })
  output$featurePreview <- renderDT({ req(rv$cleaned); datatable(rv$cleaned) })
}

  # 2.5 Exploratory Data Analysis Server

  # 2.6 Download & Reset Server

# 3. Run the application
shinyApp(ui, server)
