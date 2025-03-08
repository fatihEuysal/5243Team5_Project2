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
                 h4("Feature Engineered Data"),
                 DTOutput("featureEngPreview")
               )
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
  observeEvent(input$applyFeatureEng, {
    req(rv$cleaned)  # Ensure data is loaded
    data <- rv$cleaned  # Copy data
    
    # Mathematical transformations
    if ("log" %in% input$mathTransform) {
      data <- data %>% mutate(across(where(is.numeric), ~ log(. + 1)))
    }
    if ("sqrt" %in% input$mathTransform) {
      data <- data %>% mutate(across(where(is.numeric), sqrt))
    }
    if ("square" %in% input$mathTransform) {
      data <- data %>% mutate(across(where(is.numeric), ~ .^2))
    }
    
    # Time feature extraction (Fixed for-loop)
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
    if ("var_thresh" %in% input$featureSelection) {
      variances <- apply(select(data, where(is.numeric)), 2, var)
      data <- data[, variances > 0.01, drop = FALSE]  # Remove low-variance features
    }
    
    if ("corr" %in% input$featureSelection) {
      corr_matrix <- cor(select(data, where(is.numeric)), use = "pairwise.complete.obs")
      high_corr <- findCorrelation(corr_matrix, cutoff = 0.8)  # Correlation > 0.8
      data <- data[, -high_corr, drop = FALSE]
    }
    
    if ("lasso" %in% input$featureSelection) {
      if (requireNamespace("glmnet", quietly = TRUE)) {
        num_data <- select(data, where(is.numeric))
        x <- as.matrix(num_data)
        y <- rep(1, nrow(data))  # LASSO requires a target variable, using a default placeholder
        lasso_model <- glmnet::cv.glmnet(x, y, alpha = 1)
        selected_features <- coef(lasso_model, s = "lambda.min")[-1, ]  # Select non-zero features
        data <- data[, names(selected_features), drop = FALSE]
      } else {
        showNotification("Lasso Regularization requires 'glmnet' package.", type = "error")
      }
    }
    
    # Dimensionality reduction
    if ("pca" %in% input$dimReduction) {
      pca_result <- prcomp(select(data, where(is.numeric)), scale. = TRUE)
      data <- as.data.frame(pca_result$x[, 1:2])  # Keep only the first 2 principal components
    }
    
    if ("lda" %in% input$dimReduction) {
      if (requireNamespace("MASS", quietly = TRUE)) {
        lda_result <- MASS::lda(select(data, where(is.numeric)), grouping = rep(1, nrow(data))) 
        data <- as.data.frame(predict(lda_result)$x)
      } else {
        showNotification("LDA requires 'MASS' package.", type = "error")
      }
    }
    
    if ("tsne" %in% input$dimReduction) {
      if (requireNamespace("Rtsne", quietly = TRUE)) {
        tsne_result <- Rtsne::Rtsne(select(data, where(is.numeric)))
        data <- as.data.frame(tsne_result$Y)
      } else {
        showNotification("t-SNE requires 'Rtsne' package.", type = "error")
      }
    }
    
    # Update feature-engineered data
    rv$cleaned <- data
    output$featureEngPreview <- renderDT({ datatable(data) })
    
    showNotification("Feature Engineering Applied Successfully", type = "message")
  })
}
  

  # 2.5 Exploratory Data Analysis Server

  # 2.6 Download & Reset Server

# 3. Run the application
shinyApp(ui, server)
