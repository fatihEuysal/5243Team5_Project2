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
library(lubridate) # Date handling
library(ggcorrplot) # Correlation plot
library(rmarkdown)  # For report generation
library(DBI)        # For database connections
library(shinyWidgets)  # For enhanced UI elements



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
                 h4("Feature Engineering Options"),
                 
                 # Select mathematical transformations
                 checkboxGroupInput("mathTransform", "Mathematical Transformations:",
                                    choices = c("Log" = "log", "Square Root" = "sqrt", "Square" = "square")),
                 
                 # Select time feature extraction
                 checkboxInput("extractTimeFeatures", "Extract Time Features", value = FALSE),
                 
                 # Select text feature extraction
                 checkboxInput("extractTextFeatures", "Extract Text Features (Word Count, Character Count)", value = FALSE),
                 
                 # Select statistical feature generation
                 checkboxInput("generateStats", "Generate Statistical Features (Mean, Variance, etc.)", value = FALSE),
                 
                 # Select feature selection methods
                 checkboxGroupInput("featureSelection", "Feature Selection Methods:",
                                    choices = c("Variance Threshold" = "var_thresh", 
                                                "Correlation Analysis" = "corr",
                                                "Lasso Regularization" = "lasso")),
                 
                 # Select dimensionality reduction methods
                 checkboxGroupInput("dimReduction", "Dimensionality Reduction:",
                                    choices = c("PCA" = "pca", "LDA" = "lda", "t-SNE" = "tsne")),
                 
                 actionButton("applyFeatureEng", "Apply Feature Engineering")
               ),
               
               mainPanel(
                 h4("Preview: Before & After Feature Engineering"),
                 tabsetPanel(
                   tabPanel("Before Feature Engineering", DTOutput("beforeFeatureEngPreview")),
                   tabPanel("After Feature Engineering", DTOutput("featureEngPreview"))
                 )
               )
             )),
             
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
                      )),
             
             # 1.6 Download Data Tab
             tabPanel("Download Data", fluidRow(
               column(12,
                      h4("Download Processed Data"),
                      p("Download your processed dataset in different formats."),
                      selectInput("downloadFormat", "Select Format:",
                                  choices = c("CSV", "Excel", "RDS"), selected = "CSV"),
                      downloadButton("downloadData", "Download"),
                      hr(),
                      h4("Save/Export Analysis Report"),
                      selectInput("reportFormat", "Select Format:",
                                  choices = c("HTML", "PDF"), selected = "HTML"),
                      downloadButton("downloadReport", "Generate Report")
               )
             ))
  ),
  
  # Add Reset button and error handling outside of navbarPage
  fluidRow(
    column(12,
           actionButton("resetApp", "Reset Application", class = "btn-danger")
    )
  )
)

# Add global error handling
options(shiny.error = function() {
  # Log the error for debugging
  write(conditionMessage(attr(last.dump, "error")), file = "error_log.txt", append = TRUE)
  
  # Display a user-friendly error message
  showModal(modalDialog(
    title = "Error",
    "An error occurred. Please check your inputs or try reloading the application.",
    easyClose = TRUE,
    footer = NULL
  ))
})

# 2. Define Server logic
server <- function(input, output, session) {
  rv <- reactiveValues(data = NULL, cleaned = NULL, featured = NULL)
  
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
  
  # Display Data Preview & Data Structure
  output$dataPreview <- renderDT({ req(rv$data); datatable(rv$data) })
  output$dataStructure <- renderPrint({ req(rv$data); str(rv$data) })
  
  # Display Before Clean Preview
  output$beforeCleanPreview <- renderDT({ req(rv$data); datatable(rv$data, options = list(scrollX = TRUE)) })
  
  
  # 2.2 Data Cleaning & Preprocessing Server
  observeEvent(input$clean, {
    req(rv$data)
    data <- rv$data
    
    # Data cleaning (removing duplicates, handling missing values, handling outliers, etc.)
    if (input$removeDup) {
      data <- distinct(data)
    }
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
    
    # Normalization
    if (input$normalizeData) {
      data <- data %>% mutate(across(where(is.numeric), ~ ( . - min(., na.rm = TRUE)) / (max(., na.rm = TRUE) - min(., na.rm = TRUE))))
    }
    
    # Categorical encoding
    if (input$encodeCategorical) {
      data <- data %>% mutate(across(where(is.character), as.factor))
    }
    
    # Update cleaned data
    rv$cleaned <- data
    
    # Send notification
    showNotification("Data cleaned successfully", type = "message")
  })

  
  # Display data after cleaning
  output$cleanPreview <- renderDT({ req(rv$cleaned); datatable(rv$cleaned, options = list(scrollX = TRUE)) })
  
  # Display data before feature engneering
  output$beforeFeatureEngPreview <- renderDT({ datatable(rv$cleaned, options = list(scrollX = TRUE)) })
  
  
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


  # 2.5 Download & Reset Server
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("processed_data_", Sys.Date(), switch(input$downloadFormat,
                                                  "CSV" = ".csv",
                                                  "Excel" = ".xlsx",
                                                  "RDS" = ".rds"), sep = "")
    },
    content = function(file) {
      # Determine which dataset to download
      data_to_download <- rv$featured
      if (is.null(data_to_download)) {
        data_to_download <- rv$cleaned
      }
      if (is.null(data_to_download)) {
        data_to_download <- rv$data
      }
      
      req(data_to_download)
      
      switch(input$downloadFormat,
             "CSV" = write.csv(data_to_download, file, row.names = FALSE),
             "Excel" = write.xlsx(data_to_download, file),
             "RDS" = saveRDS(data_to_download, file))
    }
  )
  
  # 2.6 Reset functionality
  observeEvent(input$resetApp, {
    # Reset all reactive values
    rv$data <- NULL
    rv$cleaned <- NULL
    rv$featured <- NULL
    
    # Reset file input
    reset("file")
    
    # Reset all checkboxes and selections
    updateRadioButtons(session, "dataSource", selected = "upload")
    updateCheckboxInput(session, "removeDup", value = TRUE)
    updateCheckboxInput(session, "handleMissing", value = FALSE)
    updateCheckboxInput(session, "handleOutliers", value = FALSE)
    updateCheckboxInput(session, "normalizeData", value = FALSE)
    updateCheckboxInput(session, "encodeCategorical", value = FALSE)
    
    # Show notification
    showNotification("Application has been reset", type = "message")
  })
}
# 3. Run the application
shinyApp(ui, server)

# Run with specific host and port
shiny::runApp('data_explorer_app_trial.R', host = "127.0.0.1", port = 4718)