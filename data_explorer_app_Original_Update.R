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
library(lubridate)
library(ggcorrplot)
library(recipes)
library(caret)
library(reshape2)
library(MASS)           # For Box-Cox
library(rmarkdown)      # For report generation
library(DBI)            # For database connections
library(shinyWidgets)

# 1. Define UI
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: #f8f8f8; color: #333; overflow-y: auto; }
      .container { background: #ffffff; padding: 20px; border-radius: 8px; margin-top: 20px; margin-bottom: 20px; }
      .navbar, .navbar-default { background-color: #222222 !important; border-color: #222222; }
      .navbar .navbar-nav > li > a { color: #ffffff !important; }
      .dataTables_wrapper .dataTables_paginate .paginate_button { color: #333333 !important; }
      /* Tooltip styling for datatable headers */
      th { position: relative; }
      th:hover::after {
        content: attr(title);
        position: absolute; top: 100%; left: 0;
        background: #333; color: #fff; padding: 3px 5px;
        white-space: nowrap; z-index: 100; border-radius: 3px;
      }
      /* Custom styles for selectize multi-select */
      .selectize-control.multi .selectize-input [data-value] {
        padding: 2px 20px 2px 8px !important; position: relative;
      }
      .selectize-control.multi .selectize-input [data-value] .remove {
        position: absolute; top: 0; right: 0; width: 20px; height: 100%;
        display: flex; align-items: center; justify-content: center;
        border-left: 1px solid rgba(0,0,0,0.1); background: rgba(0,0,0,0.05); cursor: pointer;
      }
      .selectize-control.multi .selectize-input [data-value] .remove:hover { background: rgba(0,0,0,0.1); }
    "))
  ),
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
                        tags$li(strong("Data Upload:"), "Supports CSV, Excel, JSON, and RDS files"),
                        tags$li(strong("Data Cleaning:"), "Remove duplicates, handle missing values, outliers, normalize/standardize, encode categorical variables, and convert numeric-like columns"),
                        tags$li(strong("Feature Engineering:"), "Apply mathematical transformations, create custom columns, and rename columns"),
                        tags$li(strong("EDA:"), "Generate interactive histograms, boxplots, bar charts, scatter plots, and correlation heatmaps"),
                        tags$li(strong("Download:"), "Export the cleaned data"),
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
                 h4(strong("Data Source Options")),
                 radioButtons("dataSource", "Data Source:",
                              choices = c("Upload File(s)" = "upload", "Use Built-in Dataset(s)" = "builtin"),
                              selected = "upload"),
                 conditionalPanel(
                   condition = "input.dataSource == 'upload'",
                   fileInput("file", "Choose dataset file(s):",
                             accept = c(".csv", ".xlsx", ".json", ".rds"),
                             multiple = TRUE)
                 ),
                 conditionalPanel(
                   condition = "input.dataSource == 'builtin'",
                   selectizeInput("builtinDataset", "Select built-in dataset(s):",
                                  choices = c("mtcars", "iris", "ToothGrowth"),
                                  multiple = TRUE,
                                  selected = "mtcars",
                                  options = list(plugins = list('remove_button')))
                 ),
                 actionButton("loadData", "Load Data")
               ),
               mainPanel(
                 div(class = "container",
                     h4("Preview Loaded Dataset"),
                     selectInput("uploadPreview", "Select Dataset to Preview:", choices = NULL),
                     DTOutput("dataPreview", height = "300px")
                 )
               )
             )),
             
             # 1.3 Data Cleaning & Preprocessing Part
             tabPanel("Data Cleaning & Preprocessing",
                      sidebarLayout(
                        sidebarPanel(
                          h4(strong("Cleaning Options")),
                          
                          # 1. Dataset Selection
                          selectInput("activeDataset", "Select Active Dataset:", choices = NULL),
                          
                          # 2. Data Handling
                          strong("General Data Handling"),
                          checkboxInput("removeDup", "Remove duplicate rows", value = FALSE),
                          checkboxInput("handleMissing", "Handle Missing Values", value = FALSE),
                          conditionalPanel(
                            condition = "input.handleMissing == true",
                            radioButtons("missOpt", "Missing Value Handling Method:",
                                         choices = c("Remove Rows" = "remove", 
                                                     "Impute with Mean" = "mean",
                                                     "Impute with Median" = "median",
                                                     "Impute with Mode" = "mode",
                                                     "Impute with KNN" = "knn"),
                                         selected = "remove")
                          ),
                          checkboxInput("handleOutliers", "Handle Outliers", value = FALSE),
                          conditionalPanel(
                            condition = "input.handleOutliers == true",
                            radioButtons("outlierMethod", "Outlier Detection Method:",
                                         choices = c("Z-score" = "zscore", "IQR" = "iqr"),
                                         selected = "zscore")
                          ),
                          checkboxInput("roundValues", "Round numeric values", value = FALSE),
                          conditionalPanel(
                            condition = "input.roundValues == true",
                            numericInput("roundDigits", "Round to how many decimal places:", value = 2, min = 0, max = 10)
                          ),
                          
                          # 3. Feature Transformations
                          strong("Feature Transformations"),
                          checkboxInput("normalizeData", "Normalize Numerical Features", value = FALSE),
                          checkboxInput("standardizeData", "Standardize Numerical Features", value = FALSE),
                          checkboxInput("encodeCategorical", "Encode Categorical Variables", value = FALSE),
                          checkboxInput("convertNumeric", "Convert numeric-like character columns to numeric", value = FALSE),
                          
                          # 4. Column Management
                          strong("Column Management"),
                          checkboxInput("removeColumns", "Select Columns to Remove", value = FALSE),
                          conditionalPanel(
                            condition = "input.removeColumns == true",
                            checkboxGroupInput("colsToRemove", "Columns to Remove:", choices = NULL)
                          ),
                          br(),
                          
                          # 5. Execute Cleaning
                          actionButton("clean", "Clean Data", class = "btn-primary")
                        ),
                        
                        mainPanel(
                          div(class = "container",
                              h4("Cleaning Summary"),
                              uiOutput("cleaningSummary"),
                          ),
                          div(class = "container",
                              tabsetPanel(
                                tabPanel("Before Cleaning", DTOutput("beforeCleanPreview", height = "350px")),
                                tabPanel("After Cleaning", DTOutput("cleanPreview", height = "350px"))
                              )
                          )
                        )
                      )
             )
             ,
             
             # 1.4 Feature Engineering Part
             tabPanel("Feature Engineering",
                      sidebarLayout(
                        sidebarPanel(
                          h4(strong("Feature Engineering Options")),
                          
                          # Select Active Dataset
                          selectInput("featureActiveDataset", "Select Active Dataset:", choices = NULL),
                          
                          # Mathematical transformations
                          checkboxGroupInput("mathTransform", "Mathematical Transformations:",
                                             choices = c("Log" = "log", "Square Root" = "sqrt", "Square" = "square")),
                          
                          # Feature selection
                          checkboxGroupInput("featureSelection", "Feature Selection Methods:",
                                             choices = c("Variance Threshold" = "var_thresh", 
                                                         "Correlation Analysis" = "corr",
                                                         "Lasso Regularization" = "lasso")),
                          
                          # Dimensionality reduction
                          checkboxGroupInput("dimReduction", "Dimensionality Reduction:",
                                             choices = c("PCA" = "pca", "LDA" = "lda", "t-SNE" = "tsne")),
                          
                          # Additional feature engineering
                          checkboxGroupInput("additionalFeatureEng", "Additional Feature Engineering:",
                                             choices = c("Extract Time Features" = "time",
                                                         "Extract Text Features" = "text",
                                                         "Generate Statistical Features" = "stats")),
                          
                          br(),
                          actionButton("applyFeatureEng", "Apply Feature Engineering")
                        ),
                        
                        # Right-side main panel
                        mainPanel(
                          div(class = "container",
                              h4("Feature Engineering Summary"),
                              uiOutput("featureEngineeringSummary")
                          ),
                          div(class = "container",
                              h4("Preview: Before & After Feature Engineering"),
                              tabsetPanel(
                                tabPanel("Before Feature Engineering", DTOutput("beforeFeatureEngPreview")),
                                tabPanel("After Feature Engineering", DTOutput("featureEngPreview"))
                              )
                          )
                        )
                      ))
             ,
             
             # 1.5 Exploratory Data Analysis Part
             tabPanel("Exploratory Data Analysis", 
                      sidebarLayout(
                        sidebarPanel(
                          h4("Select Variables and Parameters"),
                          selectInput("xVar", "Select X-axis Variable:", choices = NULL),
                          selectInput("yVar", "Select Y-axis Variable:", choices = NULL, selected = NULL),
                          selectInput("colorVar", "Select Grouping Variable:", choices = c("None"), selected = "None"),
                          radioButtons("plotType", "Select Chart Type:", 
                                       choices = c("Histogram" = "hist", "Boxplot" = "boxplot", 
                                                   "Bar Chart" = "bar", "Scatter Plot" = "scatter", 
                                                   "Correlation Heatmap" = "heatmap"),
                                       selected = "hist"),
                          sliderInput("alpha", "Opacity:", min = 0.1, max = 1, value = 0.7),
                          actionButton("plotData", "Generate Plot")
                        ),
                        
                        mainPanel(
                          h4("Data Exploration Visualization"),
                          conditionalPanel(
                            condition = "input.plotType == 'heatmap'", 
                            plotOutput("heatmapPlot", height = "500px")
                          ),
                          conditionalPanel(
                            condition = "input.plotType != 'heatmap'", 
                            plotlyOutput("edaPlot", height = "500px")
                          )
                        )
                      ))
  )
)


# 2. Define Server logic
server <- function(input, output, session) {
  rv <- reactiveValues(data = list(), cleaned = list(), featured = list())
  
  # 2.1 Data Load Server
  observeEvent(input$loadData, {
    req(input$dataSource)
    
    if (input$dataSource == "upload") {
      req(input$file)
      data_list <- list()  # Store multiple datasets
      
      for (i in 1:nrow(input$file)) {
        ext <- tolower(tools::file_ext(input$file$name[i]))
        data <- switch(ext,
                       csv = read_csv(input$file$datapath[i]),
                       xlsx = read_excel(input$file$datapath[i]),
                       json = fromJSON(input$file$datapath[i], flatten = TRUE),
                       rds = readRDS(input$file$datapath[i]),
                       { showNotification(paste("Unsupported file type:", ext), type = "error"); next }
        )
        if (!is.null(data)) {
          data_list[[input$file$name[i]]] <- data  # Store dataset in list with filename as the key
        }
      }
      
      rv$dataList <- data_list  # Store multiple datasets
    } else {
      req(input$builtinDataset)
      data_list <- setNames(lapply(input$builtinDataset, get), input$builtinDataset)
      rv$dataList <- data_list
    }
    
    # Update dropdown menu (allow users to select the dataset for preview)
    updateSelectInput(session, "uploadPreview", choices = names(rv$dataList), selected = names(rv$dataList)[1])
    
    showNotification("Data successfully loaded!", type = "message")
  })
  
  # Display data preview
  output$dataPreview <- renderDT({
    req(rv$dataList, input$uploadPreview)
    datatable(rv$dataList[[input$uploadPreview]], options = list(scrollX = TRUE))
  })
  
  # Display data structure
  output$dataStructure <- renderPrint({
    req(rv$dataList, input$uploadPreview)
    str(rv$dataList[[input$uploadPreview]])
  })
  
  # Display raw data before cleaning
  output$beforeCleanPreview <- renderDT({
    req(rv$dataList, input$uploadPreview)
    datatable(rv$dataList[[input$uploadPreview]], options = list(scrollX = TRUE))
  })
  
  

  # 2.2 Data Cleaning & Preprocessing Server
  # Monitor changes in `activeDataset`, update Before Cleaning preview, and hide After Cleaning
  observe({
    req(rv$dataList, input$activeDataset)
    
    dataset_name <- input$activeDataset
    
    # Before Cleaning: Immediately display the original dataset
    output$beforeCleanPreview <- renderDT({
      req(rv$dataList[[dataset_name]])
      datatable(rv$dataList[[dataset_name]], options = list(scrollX = TRUE))
    })
    
    # After Cleaning: Display an empty table until Clean Data is clicked
    output$cleanPreview <- renderDT({
      datatable(data.frame(), options = list(scrollX = TRUE))
    })
  })
  
  # Monitor Clean Data button click and update After Cleaning preview
  observeEvent(input$clean, {
    req(rv$dataList, input$activeDataset)
    
    dataset_name <- input$activeDataset
    data <- rv$dataList[[dataset_name]]  # Retrieve original dataset
    
    # Remove duplicates
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
      } else if (input$missOpt == "knn") {
        if (!requireNamespace("DMwR", quietly = TRUE)) {
          showNotification("KNN Imputation requires 'DMwR' package. Please install it.", type = "error")
        } else {
          data <- DMwR::knnImputation(data)
        }
      }
    }
    
    # Handle outliers
    if (input$handleOutliers) {
      if (input$outlierMethod == "zscore") {
        data <- data %>% mutate(across(where(is.numeric), ~ case_when(
          abs((. - mean(., na.rm = TRUE)) / sd(., na.rm = TRUE)) > 3 ~ NA_real_,
          TRUE ~ .
        )))
      } else if (input$outlierMethod == "iqr") {
        data <- data %>% mutate(across(where(is.numeric), ~ {
          Q1 <- quantile(., 0.25, na.rm = TRUE)
          Q3 <- quantile(., 0.75, na.rm = TRUE)
          IQR_value <- Q3 - Q1
          case_when(
            . < (Q1 - 1.5 * IQR_value) ~ NA_real_,
            . > (Q3 + 1.5 * IQR_value) ~ NA_real_,
            TRUE ~ .
          )
        }))
      }
    }
    
    # Standardization & Normalization
    if (input$normalizeData) {
      data <- data %>% mutate(across(where(is.numeric), ~ (. - min(., na.rm = TRUE)) / (max(., na.rm = TRUE) - min(., na.rm = TRUE))))
    }
    if (input$standardizeData) {
      data <- data %>% mutate(across(where(is.numeric), ~ (. - mean(., na.rm = TRUE)) / sd(., na.rm = TRUE)))
    }
    
    # Categorical encoding
    if (input$encodeCategorical) {
      data <- data %>% mutate(across(where(is.character), as.factor))
    }
    
    # Numeric conversion
    if (input$convertNumeric) {
      data <- data %>% mutate(across(where(is.character), ~ ifelse(suppressWarnings(!is.na(as.numeric(.))), as.numeric(.), .)))
    }
    
    # Remove selected columns
    if (!is.null(input$colsToRemove) && length(input$colsToRemove) > 0) {
      remaining_cols <- setdiff(names(data), input$colsToRemove)
      
      # Prevent the user from removing all columns
      if (length(remaining_cols) > 0) {
        data <- data[, remaining_cols, drop = FALSE]
      } else {
        showNotification("Cannot remove all columns!", type = "error")
        return()
      }
    }
    
    # Rounding values
    if (input$roundValues) {
      data <- data %>% mutate(across(where(is.numeric), ~ round(., input$roundDigits)))
    }
    
    # Update cleaned data
    rv$cleaned[[dataset_name]] <- data
    
    # Update After Cleaning preview
    output$cleanPreview <- renderDT({
      req(rv$cleaned[[dataset_name]])
      datatable(rv$cleaned[[dataset_name]], options = list(scrollX = TRUE))
    })
    
    # Update Before Feature Engineering preview
    output$beforeFeatureEngPreview <- renderDT({
      req(rv$cleaned[[dataset_name]])
      datatable(rv$cleaned[[dataset_name]], options = list(scrollX = TRUE))
    })
    
    # Update `colsToRemove` checkbox group
    updateCheckboxGroupInput(session, "colsToRemove", choices = names(data), selected = NULL)
    
    # Update Cleaning Summary
    output$cleaningSummary <- renderUI({
      req(rv$dataList, rv$cleaned, input$activeDataset)
      
      original_rows <- nrow(rv$dataList[[dataset_name]])
      cleaned_rows <- nrow(rv$cleaned[[dataset_name]])
      removed_cols <- ifelse(length(input$colsToRemove) > 0, paste(input$colsToRemove, collapse = ", "), "None")
      
      tags$div(
        h5("Cleaning Summary:"),
        p(paste("Dataset:", dataset_name)),
        p(paste("Original Rows:", original_rows)),
        p(paste("Rows After Cleaning:", cleaned_rows)),
        p(paste("Columns Removed:", removed_cols))
      )
    })
    
    # Notify the user
    showNotification(paste("Data cleaning completed successfully for:", dataset_name), type = "message")
  })
  
  # Dynamically update `activeDataset` selection input
  observe({
    req(rv$dataList)
    updateSelectInput(session, "activeDataset", choices = names(rv$dataList), selected = names(rv$dataList)[1])
  })

  
  
  
  # 2.3 Feature Engineering Server
  observeEvent(input$applyFeatureEng, {
    req(rv$cleaned)  # Cleaned data
    data <- rv$cleaned  # Start Feature Engineering from cleaned data  
    
    # Mathematical transformations
    if (!is.null(input$mathTransform)) {
      if ("log" %in% input$mathTransform) {
        data <- data %>% mutate(across(where(is.numeric), ~ log(. + 1), .names = "log_{.col}"))
      }
      if ("sqrt" %in% input$mathTransform) {
        data <- data %>% mutate(across(where(is.numeric), sqrt, .names = "sqrt_{.col}"))
      }
      if ("square" %in% input$mathTransform) {
        data <- data %>% mutate(across(where(is.numeric), ~ .^2, .names = "square_{.col}"))
      }
    }
    
    # Time feature extraction
    if (input$extractTimeFeatures) {
      date_cols <- names(select(data, where(lubridate::is.Date)))
      if (length(date_cols) > 0) {
        for (col in date_cols) {
          data[[paste0(col, "_year")]] <- lubridate::year(data[[col]])
          data[[paste0(col, "_month")]] <- lubridate::month(data[[col]])
          data[[paste0(col, "_day")]] <- lubridate::day(data[[col]])
          data[[paste0(col, "_weekday")]] <- lubridate::wday(data[[col]], label = TRUE)
        }
      }
    }
    
    # Text feature extraction
    if (input$extractTextFeatures) {
      text_cols <- names(select(data, where(is.character)))
      if (length(text_cols) > 0) {
        for (col in text_cols) {
          data[[paste0(col, "_word_count")]] <- str_count(data[[col]], "\\S+")
          data[[paste0(col, "_char_count")]] <- nchar(data[[col]])
        }
      }
    }
    
    # Statistical features
    if (input$generateStats) {
      num_cols <- names(select(data, where(is.numeric)))
      if (length(num_cols) > 0) {
        for (col in num_cols) {
          data[[paste0(col, "_mean")]] <- mean(data[[col]], na.rm = TRUE)
          data[[paste0(col, "_var")]] <- var(data[[col]], na.rm = TRUE)
          data[[paste0(col, "_median")]] <- median(data[[col]], na.rm = TRUE)
          data[[paste0(col, "_min")]] <- min(data[[col]], na.rm = TRUE)
          data[[paste0(col, "_max")]] <- max(data[[col]], na.rm = TRUE)
        }
      }
    }
    
    # Feature selection
    if (!is.null(input$featureSelection)) {
      if ("var_thresh" %in% input$featureSelection) {
        variances <- apply(select(data, where(is.numeric)), 2, var)
        low_var_cols <- names(variances[variances <= 0.01])
        data <- select(data, -all_of(low_var_cols))  # Remove low-variance features
      }
      
      if ("corr" %in% input$featureSelection) {
        corr_matrix <- cor(select(data, where(is.numeric)), use = "pairwise.complete.obs")
        high_corr <- caret::findCorrelation(corr_matrix, cutoff = 0.8)  # Correlation > 0.8
        data <- data[, -high_corr, drop = FALSE]
      }
    }
    
    # Dimensionality reduction
    if (!is.null(input$dimReduction)) {
      if ("pca" %in% input$dimReduction) {
        pca_result <- prcomp(select(data, where(is.numeric)), scale. = TRUE)
        pca_df <- as.data.frame(pca_result$x[, 1:2])  # Keep only the first 2 principal components
        colnames(pca_df) <- c("PCA_1", "PCA_2")
        data <- cbind(data, pca_df)  # Append dimensionality reduction features
      }
    }
    
    # Update Feature Engineering results
    rv$featured <- data
    
    showNotification("Feature Engineering Applied Successfully", type = "message")
  })
  
  output$featureEngPreview <- renderDT({ datatable(rv$featured, options = list(scrollX = TRUE)) })
  
  
  # 2.4 Exploratory Data Analysis Server
  # After Feature Engineering is completed, update the variable selection dropdowns
  observeEvent(rv$featured, {
    req(rv$featured)
    updateSelectInput(session, "xVar", choices = names(rv$featured))
    updateSelectInput(session, "yVar", choices = c("", names(rv$featured)), selected = "")
    updateSelectInput(session, "colorVar", choices = c("None", names(rv$featured)), selected = "None")
  })
  
  observeEvent(input$plotData, {
    req(rv$featured, input$xVar, input$plotType)
    
    #Generate correlation heatmap to interpret the relationship between variables
    if (input$plotType == "heatmap") {
      corr_matrix <- cor(select(rv$featured, where(is.numeric)), use = "pairwise.complete.obs")
      output$heatmapPlot <- renderPlot({
        ggcorrplot::ggcorrplot(corr_matrix, lab = TRUE, outline.color = "white")
      })
    }
    
    else {
      # First, check if the colorVar variable is "None". If so, do not set a color mapping.
      color_mapping <- if (input$colorVar == "None") NULL else input$colorVar
      
      # Initialize ggplot
      p <- ggplot(rv$featured, aes_string(x = input$xVar))
      
      # Generate the plot based on the selected chart type
      if (input$plotType == "hist") {
        p <- p + geom_histogram(alpha = input$alpha, fill = "blue", bins = 30)
      } else if (input$plotType == "boxplot") {
        req(input$yVar)  # Boxplot requires a Y-axis variable
        if (is.null(color_mapping)) {
          p <- p + geom_boxplot(aes_string(y = input$yVar))
        } else {
          p <- p + geom_boxplot(aes_string(y = input$yVar, fill = color_mapping))
        }
      } else if (input$plotType == "bar") {
        if (is.null(color_mapping)) {
          p <- p + geom_bar(stat = "count")
        } else {
          p <- p + geom_bar(stat = "count", aes_string(fill = color_mapping))
        }
      } else if (input$plotType == "scatter") {
        req(input$yVar)  # Scatter plot requires a Y-axis variable
        if (is.null(color_mapping)) {
          p <- p + geom_point(aes_string(y = input$yVar), alpha = input$alpha)
        } else {
          p <- p + geom_point(aes_string(y = input$yVar, color = color_mapping), alpha = input$alpha)
        }
      }
      
      # Ensure the plot is rendered on the right side of the page
      output$edaPlot <- renderPlotly({ ggplotly(p) })
    }
  })
}

# 2.5 Download & Reset Server

# 3. Run the application
shinyApp(ui, server)
