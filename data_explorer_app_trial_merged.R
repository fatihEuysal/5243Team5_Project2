# app.R
library(shiny)
library(shinythemes)
library(shinyjs)
library(DT)
library(dplyr)
library(openxlsx)
library(stringr)
library(readr)
library(readxl)
library(jsonlite)
library(ggplot2)
library(plotly)
library(lubridate)
library(ggcorrplot)
library(recipes)
library(caret)
library(reshape2)
library(MASS)       # For Box-Cox
library(rmarkdown)  # For report generation
library(DBI)        # For database connections
library(shinyWidgets)

# Sanitize errors so red messages are not shown in the UI
options(shiny.sanitize.errors = TRUE)

# Custom error handling: show a brief notification
safeRun <- function(expr) {
  tryCatch(expr, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error", duration = 5)
    NULL
  })
}

# Helper function to calculate the mode
Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# ----------------------- UI ----------------------- #
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: #f8f8f8; color: #333; overflow-y: auto; }
      .container { background: #ffffff; padding: 20px; border-radius: 8px; margin-top: 20px; margin-bottom: 20px; }
      .navbar, .navbar-default { background-color: #222222 !important; border-color: #222222; }
      .navbar .navbar-nav > li > a { color: #ffffff !important; }
      .dataTables_wrapper .dataTables_paginate .paginate_button { color: #333333 !important; }
    "))
  ),
  theme = shinytheme("flatly"),
  useShinyjs(),
  titlePanel("Data Explorer & Comparison Tool"),
  navbarPage("",
             # ----- User Guide Tab ----- #
             tabPanel("User Guide",
                      fluidRow(
                        column(12,
                               h3("Overview"),
                               p("This interactive web application provides an all‐in‐one platform for data analysis. You can upload datasets (CSV, Excel, JSON, RDS) or use built‐in ones, clean and preprocess your data, perform feature engineering (including mathematical transformations, custom column creation, time/text/statistical feature extraction, feature selection and dimensionality reduction), and explore your data via interactive visualizations. Finally, you can download your processed data or an analysis report."),
                               h4("Key Features:"),
                               tags$ul(
                                 tags$li("Multiple dataset support (upload and built‐in)"),
                                 tags$li("Advanced data cleaning: remove duplicates, handle missing values (with options including KNN imputation), outlier handling, normalization, standardization, and encoding categorical variables"),
                                 tags$li("Feature Engineering: Mathematical transformations (Log, Square Root, Square, Box‑Cox, Power), custom column creation & renaming, time and text feature extraction, statistical feature generation, feature selection, and dimensionality reduction"),
                                 tags$li("Exploratory Data Analysis (EDA): Generate histograms, boxplots, bar charts, scatter plots, and correlation heatmaps"),
                                 tags$li("Download processed data in multiple formats and generate analysis reports"),
                                 tags$li("Reset the application")
                               ),
                               h4("Navigation:"),
                               p("Use the tabs to navigate between Data Upload, Data Cleaning & Preprocessing, Feature Engineering, EDA, and Download & Reset.")
                        )
                      )
             ),
             # ----- Data Upload Tab ----- #
             tabPanel("Data Upload",
                      sidebarLayout(
                        sidebarPanel(
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
                                           selected = "mtcars")
                          ),
                          actionButton("loadData", "Load Data")
                        ),
                        mainPanel(
                          div(class = "container",
                              h4("Preview Loaded Dataset"),
                              selectInput("uploadPreview", "Select Dataset to Preview:", choices = NULL),
                              DTOutput("dataPreview", height = "300px"),
                              h4("Dataset Structure"),
                              verbatimTextOutput("dataStructure")
                          )
                        )
                      )
             ),
             # ----- Data Cleaning & Preprocessing Tab ----- #
             tabPanel("Data Cleaning & Preprocessing",
                      sidebarLayout(
                        sidebarPanel(
                          selectInput("activeDataset", "Select Active Dataset:", choices = NULL),
                          checkboxInput("removeDup", "Remove duplicate rows", value = TRUE),
                          checkboxInput("handleMissing", "Handle Missing Values", value = FALSE),
                          conditionalPanel(
                            condition = "input.handleMissing == true",
                            radioButtons("missOpt", "Missing Value Option:",
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
                            radioButtons("outlierMethod", "Outlier Method:",
                                         choices = c("Z-score" = "zscore", "IQR" = "iqr"),
                                         selected = "zscore")
                          ),
                          checkboxInput("normalizeData", "Normalize Numerical Features", value = FALSE),
                          checkboxInput("standardizeData", "Standardize Numerical Features", value = FALSE),
                          checkboxInput("encodeCategorical", "Encode Categorical Variables", value = FALSE),
                          checkboxGroupInput("colsToRemove", "Select Columns to Remove:", choices = NULL),
                          checkboxInput("roundValues", "Round numeric values", value = FALSE),
                          conditionalPanel(
                            condition = "input.roundValues == true",
                            numericInput("roundDigits", "Round to how many decimal places:", value = 2, min = 0, max = 10)
                          ),
                          actionButton("clean", "Clean Data")
                        ),
                        mainPanel(
                          div(class = "container",
                              h4("Preview: Before & After Cleaning"),
                              tabsetPanel(
                                tabPanel("Before Cleaning", DTOutput("beforeCleanPreview", height = "300px")),
                                tabPanel("After Cleaning", DTOutput("cleanPreview", height = "300px"))
                              ),
                              uiOutput("cleaningSummary")
                          )
                        )
                      )
             ),
             # ----- Feature Engineering Tab ----- #
             tabPanel("Feature Engineering",
                      sidebarLayout(
                        sidebarPanel(
                          selectInput("activeDatasetFE", "Select Active Dataset:", choices = NULL),
                          h4("Mathematical Transformations"),
                          checkboxGroupInput("mathTransform", "Select Transformations:",
                                             choices = c("Log" = "log", "Square Root" = "sqrt", "Square" = "square", "Box-Cox" = "boxcox", "Power" = "power")),
                          conditionalPanel(
                            condition = "input.mathTransform.indexOf('log') > -1",
                            h5("Transformation: LOG"),
                            selectInput("cols_log", "Select Columns for LOG:", choices = NULL, multiple = TRUE),
                            checkboxInput("round_log", "Round LOG columns", value = FALSE),
                            conditionalPanel(
                              condition = "input.round_log == true",
                              numericInput("roundDigits_log", "Round digits:", value = 2, min = 0, max = 10)
                            ),
                            hr()
                          ),
                          conditionalPanel(
                            condition = "input.mathTransform.indexOf('sqrt') > -1",
                            h5("Transformation: SQUARE ROOT"),
                            selectInput("cols_sqrt", "Select Columns for SQUARE ROOT:", choices = NULL, multiple = TRUE),
                            checkboxInput("round_sqrt", "Round SQUARE ROOT columns", value = FALSE),
                            conditionalPanel(
                              condition = "input.round_sqrt == true",
                              numericInput("roundDigits_sqrt", "Round digits:", value = 2, min = 0, max = 10)
                            ),
                            hr()
                          ),
                          conditionalPanel(
                            condition = "input.mathTransform.indexOf('square') > -1",
                            h5("Transformation: SQUARE"),
                            selectInput("cols_square", "Select Columns for SQUARE:", choices = NULL, multiple = TRUE),
                            checkboxInput("round_square", "Round SQUARE columns", value = FALSE),
                            conditionalPanel(
                              condition = "input.round_square == true",
                              numericInput("roundDigits_square", "Round digits:", value = 2, min = 0, max = 10)
                            ),
                            hr()
                          ),
                          conditionalPanel(
                            condition = "input.mathTransform.indexOf('boxcox') > -1",
                            h5("Transformation: BOX-COX"),
                            selectInput("cols_boxcox", "Select Columns for BOX-COX:", choices = NULL, multiple = TRUE),
                            numericInput("lambda_boxcox", "Lambda for Box-Cox:", value = 0.5, min = -5, max = 5, step = 0.1),
                            checkboxInput("round_boxcox", "Round BOX-COX columns", value = FALSE),
                            conditionalPanel(
                              condition = "input.round_boxcox == true",
                              numericInput("roundDigits_boxcox", "Round digits:", value = 2, min = 0, max = 10)
                            ),
                            hr()
                          ),
                          conditionalPanel(
                            condition = "input.mathTransform.indexOf('power') > -1",
                            h5("Transformation: POWER"),
                            selectInput("cols_power", "Select Columns for POWER:", choices = NULL, multiple = TRUE),
                            numericInput("exponent_power", "Exponent for Power:", value = 2, min = -5, max = 5, step = 0.1),
                            checkboxInput("round_power", "Round POWER columns", value = FALSE),
                            conditionalPanel(
                              condition = "input.round_power == true",
                              numericInput("roundDigits_power", "Round digits:", value = 2, min = 0, max = 10)
                            ),
                            hr()
                          ),
                          h4("Custom Columns & Rename"),
                          numericInput("numCustom", "How many custom columns to create:", value = 0, min = 0, max = 50),
                          uiOutput("customColUI"),
                          hr(),
                          numericInput("numRename", "How many columns to rename:", value = 0, min = 0, step = 1),
                          uiOutput("renameUI"),
                          hr(),
                          h4("Additional Feature Engineering"),
                          checkboxInput("extractTimeFeatures", "Extract Time Features", value = FALSE),
                          checkboxInput("extractTextFeatures", "Extract Text Features (Word Count, Character Count)", value = FALSE),
                          checkboxInput("generateStats", "Generate Statistical Features (Mean, Variance, etc.)", value = FALSE),
                          checkboxGroupInput("featureSelection", "Feature Selection Methods:",
                                             choices = c("Variance Threshold" = "var_thresh", "Correlation Analysis" = "corr", "Lasso Regularization" = "lasso")),
                          checkboxGroupInput("dimReduction", "Dimensionality Reduction:",
                                             choices = c("PCA" = "pca", "LDA" = "lda", "t-SNE" = "tsne")),
                          hr(),
                          actionButton("applyFEAll", "Apply All Feature Engineering Changes", class = "btn btn-primary"),
                          actionButton("resetFE", "Reset Feature Engineering Inputs", class = "btn btn-default", style = "margin-left:20px;")
                        ),
                        mainPanel(
                          div(class = "container",
                              h4("Feature Engineering Output"),
                              DTOutput("featureEngPreview", height = "300px")
                          )
                        )
                      )
             ),
             # ----- Exploratory Data Analysis Tab ----- #
             tabPanel("Exploratory Data Analysis",
                      sidebarLayout(
                        sidebarPanel(
                          selectInput("activeDatasetEDA", "Select Active Dataset:", choices = NULL),
                          checkboxInput("includeFE", "Include Feature Engineered Columns", value = FALSE),
                          radioButtons("plotType", "Plot Type:",
                                       choices = c("Histogram" = "hist", "Boxplot" = "boxplot", "Bar Chart" = "bar", "Scatter Plot" = "scatter", "Correlation Heatmap" = "heatmap"),
                                       selected = "hist"),
                          conditionalPanel(
                            condition = "input.plotType == 'hist'",
                            selectInput("histVar", "Select Variable:", choices = NULL)
                          ),
                          conditionalPanel(
                            condition = "input.plotType == 'boxplot'",
                            selectInput("boxVars", "Select Variables:", choices = NULL, multiple = TRUE)
                          ),
                          conditionalPanel(
                            condition = "input.plotType == 'bar'",
                            selectInput("barVars", "Select Variables:", choices = NULL, multiple = TRUE)
                          ),
                          conditionalPanel(
                            condition = "input.plotType == 'scatter'",
                            selectInput("scatterX", "Select X Variable:", choices = NULL),
                            selectInput("scatterY", "Select Y Variable:", choices = NULL)
                          ),
                          sliderInput("filterRange", "Filter X-axis Range:", min = 0, max = 100, value = c(0, 100)),
                          sliderInput("alpha", "Opacity:", min = 0.1, max = 1, value = 0.7),
                          actionButton("plotData", "Generate Plot")
                        ),
                        mainPanel(
                          div(class = "container",
                              h4("Visualization"),
                              conditionalPanel(
                                condition = "input.plotType == 'heatmap'",
                                plotOutput("heatmapPlot", height = "500px")
                              ),
                              conditionalPanel(
                                condition = "input.plotType != 'heatmap'",
                                plotlyOutput("edaPlot", height = "500px")
                              ),
                              h4("Statistical Summary"),
                              verbatimTextOutput("statsSummary")
                          )
                        )
                      )
             ),
             # ----- Download & Reset Tab ----- #
             tabPanel("Download & Reset",
                      fluidRow(
                        column(6,
                               selectInput("activeDatasetDL", "Select Dataset to Download:", choices = NULL),
                               selectInput("downloadFormat", "Select Format:",
                                           choices = c("CSV", "Excel", "RDS"), selected = "CSV"),
                               downloadButton("downloadData", "Download Processed Data")
                        ),
                        column(6,
                               br(), br(),
                               selectInput("reportFormat", "Select Report Format:",
                                           choices = c("HTML", "PDF"), selected = "HTML"),
                               downloadButton("downloadReport", "Generate Report"),
                               br(), br(),
                               actionButton("reset", "Reset Application", class = "btn btn-danger")
                        )
                      )
             )
  ),
  fluidRow(
    column(12,
           actionButton("resetApp", "Reset App (Full Reload)", class = "btn btn-danger")
    )
  )
)

# ----------------------- Server ----------------------- #
server <- function(input, output, session) {
  rv <- reactiveValues(
    datasets = list(),
    cleaned = list(),
    featured = list()
  )
  
  # ----- Data Upload ----- #
  observeEvent(input$loadData, {
    safeRun({
      if (input$dataSource == "upload") {
        req(input$file)
        files <- input$file
        for (i in seq_len(nrow(files))) {
          fname <- files$name[i]
          ext <- tolower(tools::file_ext(fname))
          data <- NULL
          if (ext == "csv") {
            data <- read_csv(files$datapath[i])
          } else if (ext %in% c("xlsx", "xls")) {
            data <- read_excel(files$datapath[i])
          } else if (ext == "json") {
            data <- fromJSON(files$datapath[i], flatten = TRUE)
          } else if (ext == "rds") {
            data <- readRDS(files$datapath[i])
          } else {
            showNotification(paste("File", fname, "type not supported"), type = "error")
            next
          }
          key <- tools::file_path_sans_ext(fname)
          rv$datasets[[key]] <- data
          rv$cleaned[[key]] <- data
        }
      } else if (input$dataSource == "builtin") {
        req(input$builtinDataset)
        for (ds in input$builtinDataset) {
          data <- get(ds)
          rv$datasets[[ds]] <- data
          rv$cleaned[[ds]] <- data
        }
      }
      datasetNames <- names(rv$datasets)
      updateSelectInput(session, "uploadPreview", choices = datasetNames)
      updateSelectInput(session, "activeDataset", choices = datasetNames)
      updateSelectInput(session, "activeDatasetFE", choices = datasetNames)
      updateSelectInput(session, "activeDatasetEDA", choices = datasetNames)
      updateSelectInput(session, "activeDatasetDL", choices = datasetNames)
      if (length(datasetNames) > 0) {
        updateCheckboxGroupInput(session, "colsToRemove", choices = names(rv$datasets[[datasetNames[1]]]))
      }
      showNotification("Data loaded successfully", type = "message")
    })
  })
  
  output$dataPreview <- renderDT({
    safeRun({
      req(input$uploadPreview)
      datatable(rv$datasets[[input$uploadPreview]], options = list(scrollX = TRUE, scrollY = "300px", paging = TRUE, pageLength = 10))
    })
  })
  
  output$dataStructure <- renderPrint({
    safeRun({
      req(input$uploadPreview)
      str(rv$datasets[[input$uploadPreview]])
    })
  })
  
  observeEvent(input$activeDataset, {
    safeRun({
      req(rv$datasets[[input$activeDataset]])
      updateCheckboxGroupInput(session, "colsToRemove", choices = names(rv$datasets[[input$activeDataset]]))
    })
  })
  
  # ----- Data Cleaning & Preprocessing ----- #
  output$beforeCleanPreview <- renderDT({
    safeRun({
      req(input$activeDataset)
      datatable(rv$datasets[[input$activeDataset]], options = list(scrollX = TRUE, scrollY = "300px", paging = TRUE, pageLength = 10))
    })
  })
  
  observeEvent(input$clean, {
    safeRun({
      req(rv$datasets[[input$activeDataset]])
      data <- rv$datasets[[input$activeDataset]]
      if (input$removeDup) data <- distinct(data)
      if (input$handleMissing) {
        if (input$missOpt == "remove") {
          data <- na.omit(data)
        } else if (input$missOpt == "mean") {
          data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))
        } else if (input$missOpt == "median") {
          data <- data %>% mutate(across(where(is.numeric), ~ ifelse(is.na(.), median(., na.rm = TRUE), .)))
        } else if (input$missOpt == "mode") {
          data <- data %>% mutate(across(where(is.character), ~ ifelse(is.na(.), Mode(.), .)))
        } else if (input$missOpt == "knn") {
          rec <- recipe(~., data = data) %>% step_impute_knn(all_numeric())
          data <- prep(rec) %>% bake(data)
        }
      }
      if (input$handleOutliers) {
        if (input$outlierMethod == "zscore") {
          zscore_outliers <- function(x) {
            z <- (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
            x[abs(z) > 3] <- NA
            return(x)
          }
          data <- data %>% mutate(across(where(is.numeric), zscore_outliers))
        } else if (input$outlierMethod == "iqr") {
          iqr_outliers <- function(x) {
            Q1 <- quantile(x, 0.25, na.rm = TRUE)
            Q3 <- quantile(x, 0.75, na.rm = TRUE)
            IQR_val <- Q3 - Q1
            x[x < (Q1 - 1.5 * IQR_val) | x > (Q3 + 1.5 * IQR_val)] <- NA
            return(x)
          }
          data <- data %>% mutate(across(where(is.numeric), iqr_outliers))
        }
      }
      if (input$normalizeData) {
        data <- data %>% mutate(across(where(is.numeric), ~ ( . - min(., na.rm = TRUE)) / (max(., na.rm = TRUE) - min(., na.rm = TRUE))))
      }
      if (input$standardizeData) {
        data <- data %>% mutate(across(where(is.numeric), ~ ( . - mean(., na.rm = TRUE)) / sd(., na.rm = TRUE), .names = "std_{.col}"))
      }
      if (input$encodeCategorical) {
        data <- data %>% mutate(across(where(is.character), ~ tryCatch(as.factor(.), error = function(e) .)))
      }
      if (!is.null(input$colsToRemove) && length(input$colsToRemove) > 0) {
        data <- data %>% select(-all_of(input$colsToRemove))
      }
      if (input$roundValues) {
        data <- data %>% mutate(across(where(is.numeric), round, digits = input$roundDigits))
      }
      rv$cleaned[[input$activeDataset]] <- data
      showNotification("Data cleaned successfully", type = "message")
      output$cleaningSummary <- renderUI({
        tags$div(
          h5("Cleaning Summary:"),
          p(paste("Original Rows:", nrow(rv$datasets[[input$activeDataset]]))),
          p(paste("Rows After Cleaning:", nrow(rv$cleaned[[input$activeDataset]]))),
          p(paste("Columns Removed:", ifelse(length(input$colsToRemove) > 0, paste(input$colsToRemove, collapse = ", "), "None")))
        )
      })
    })
  })
  
  output$cleanPreview <- renderDT({
    safeRun({
      req(input$activeDataset)
      datatable(rv$cleaned[[input$activeDataset]], options = list(scrollX = TRUE, scrollY = "300px", paging = TRUE, pageLength = 10))
    })
  })
  
  # ----- Feature Engineering ----- #
  observeEvent(input$activeDatasetFE, {
    safeRun({
      req(input$activeDatasetFE)
      num_cols <- names(rv$cleaned[[input$activeDatasetFE]])[sapply(rv$cleaned[[input$activeDatasetFE]], is.numeric)]
      updateSelectInput(session, "cols_log", choices = num_cols)
      updateSelectInput(session, "cols_sqrt", choices = num_cols)
      updateSelectInput(session, "cols_square", choices = num_cols)
      updateSelectInput(session, "cols_boxcox", choices = num_cols)
      updateSelectInput(session, "cols_power", choices = num_cols)
    })
  })
  
  output$customColUI <- renderUI({
    req(input$numCustom)
    num <- as.integer(input$numCustom)
    if (num <= 0) return(NULL)
    tagList(lapply(seq_len(num), function(i) {
      fluidRow(
        column(4, textInput(paste0("customColName_", i), paste("Custom Col", i, "Name:"))),
        column(4, textInput(paste0("customExpression_", i), paste("Custom Expression", i, ":"))),
        column(4, tagList(
          checkboxInput(paste0("roundCustom_", i), "Round?", value = FALSE),
          conditionalPanel(
            condition = sprintf("input.roundCustom_%d == true", i),
            numericInput(paste0("roundDigitsCustom_", i), "Digits:", value = 2, min = 0, max = 10)
          )
        ))
      )
    }))
  })
  
  output$renameUI <- renderUI({
    req(input$numRename)
    num <- as.integer(input$numRename)
    if (num <= 0) return(NULL)
    tagList(lapply(seq_len(num), function(i) {
      fluidRow(
        column(6, textInput(paste0("oldCol_", i), paste("Old Column", i, "Name:"))),
        column(6, textInput(paste0("newCol_", i), paste("New Column", i, "Name:")))
      )
    }))
  })
  
  observeEvent(input$applyFEAll, {
    safeRun({
      req(rv$cleaned[[input$activeDatasetFE]])
      data <- rv$cleaned[[input$activeDatasetFE]]
      
      # --- Mathematical Transformations --- #
      if (!is.null(input$mathTransform) && length(input$mathTransform) > 0) {
        if ("log" %in% input$mathTransform) {
          cols <- input$cols_log
          if (!is.null(cols)) {
            for (col in cols) {
              new_val <- log(data[[col]] + 1)
              if (isTRUE(input$round_log)) {
                new_val <- round(new_val, digits = input$roundDigits_log)
              }
              data[[paste0("log_", col)]] <- new_val
            }
          }
        }
        if ("sqrt" %in% input$mathTransform) {
          cols <- input$cols_sqrt
          if (!is.null(cols)) {
            for (col in cols) {
              new_val <- sqrt(data[[col]])
              if (isTRUE(input$round_sqrt)) {
                new_val <- round(new_val, digits = input$roundDigits_sqrt)
              }
              data[[paste0("sqrt_", col)]] <- new_val
            }
          }
        }
        if ("square" %in% input$mathTransform) {
          cols <- input$cols_square
          if (!is.null(cols)) {
            for (col in cols) {
              new_val <- data[[col]]^2
              if (isTRUE(input$round_square)) {
                new_val <- round(new_val, digits = input$roundDigits_square)
              }
              data[[paste0("square_", col)]] <- new_val
            }
          }
        }
        if ("boxcox" %in% input$mathTransform) {
          cols <- input$cols_boxcox
          if (!is.null(cols)) {
            for (col in cols) {
              shift <- if (min(data[[col]], na.rm = TRUE) <= 0) abs(min(data[[col]], na.rm = TRUE)) + 1 else 0
              x_shifted <- data[[col]] + shift
              lambda <- input$lambda_boxcox
              if (abs(lambda) < .Machine$double.eps) {
                new_val <- log(x_shifted)
              } else {
                new_val <- (x_shifted^lambda - 1) / lambda
              }
              if (isTRUE(input$round_boxcox)) {
                new_val <- round(new_val, digits = input$roundDigits_boxcox)
              }
              data[[paste0("boxcox_", col)]] <- new_val
            }
          }
        }
        if ("power" %in% input$mathTransform) {
          cols <- input$cols_power
          if (!is.null(cols)) {
            for (col in cols) {
              exponent <- input$exponent_power
              new_val <- data[[col]]^exponent
              if (isTRUE(input$round_power)) {
                new_val <- round(new_val, digits = input$roundDigits_power)
              }
              data[[paste0("power_", col)]] <- new_val
            }
          }
        }
      }
      
      # --- Custom Column Creation --- #
      if (!is.null(input$numCustom) && as.integer(input$numCustom) > 0) {
        numCustom <- as.integer(input$numCustom)
        for (i in seq_len(numCustom)) {
          newName <- input[[paste0("customColName_", i)]]
          exprText <- input[[paste0("customExpression_", i)]]
          if (!is.null(newName) && newName != "" && !is.null(exprText) && exprText != "") {
            new_val <- safeRun(with(data, eval(parse(text = exprText))))
            if (!is.null(new_val)) {
              if (isTRUE(input[[paste0("roundCustom_", i)]])) {
                roundDigits <- input[[paste0("roundDigitsCustom_", i)]]
                new_val <- round(new_val, digits = roundDigits)
              }
              data[[newName]] <- new_val
            }
          }
        }
      }
      
      # --- Rename Columns --- #
      if (!is.null(input$numRename) && as.integer(input$numRename) > 0) {
        numRename <- as.integer(input$numRename)
        for (i in seq_len(numRename)) {
          oldName <- input[[paste0("oldCol_", i)]]
          newName <- input[[paste0("newCol_", i)]]
          if (!is.null(oldName) && oldName != "" && !is.null(newName) && newName != "") {
            if (oldName %in% names(data)) {
              names(data)[names(data) == oldName] <- newName
            } else {
              showNotification(paste("Old column name", oldName, "not found."), type = "error")
            }
          }
        }
      }
      
      # --- Additional Feature Engineering --- #
      # Extract Time Features
      if (isTRUE(input$extractTimeFeatures)) {
        date_cols <- names(data)[sapply(data, lubridate::is.Date)]
        if (length(date_cols) > 0) {
          for (col in date_cols) {
            data[[paste0(col, "_year")]] <- lubridate::year(data[[col]])
            data[[paste0(col, "_month")]] <- lubridate::month(data[[col]])
            data[[paste0(col, "_day")]] <- lubridate::day(data[[col]])
            data[[paste0(col, "_weekday")]] <- lubridate::wday(data[[col]], label = TRUE)
          }
        }
      }
      
      # Extract Text Features
      if (isTRUE(input$extractTextFeatures)) {
        text_cols <- names(data)[sapply(data, is.character)]
        if (length(text_cols) > 0) {
          for (col in text_cols) {
            data[[paste0(col, "_word_count")]] <- str_count(data[[col]], "\\S+")
            data[[paste0(col, "_char_count")]] <- nchar(data[[col]])
          }
        }
      }
      
      # Generate Statistical Features
      if (isTRUE(input$generateStats)) {
        num_cols <- names(data)[sapply(data, is.numeric)]
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
      
      # Feature Selection Methods
      if (!is.null(input$featureSelection)) {
        if ("var_thresh" %in% input$featureSelection) {
          variances <- apply(select(data, where(is.numeric)), 2, var, na.rm = TRUE)
          low_var_cols <- names(variances[variances <= 0.01])
          if(length(low_var_cols) > 0) {
            data <- data %>% select(-all_of(low_var_cols))
          }
        }
        if ("corr" %in% input$featureSelection) {
          corr_matrix <- cor(select(data, where(is.numeric)), use = "pairwise.complete.obs")
          high_corr <- caret::findCorrelation(corr_matrix, cutoff = 0.8)
          if(length(high_corr) > 0) {
            data <- data[ , -high_corr, drop = FALSE]
          }
        }
        if ("lasso" %in% input$featureSelection) {
          showNotification("Lasso Regularization is not implemented in this demo.", type = "warning")
        }
      }
      
      # Dimensionality Reduction
      if (!is.null(input$dimReduction)) {
        if ("pca" %in% input$dimReduction) {
          pca_result <- prcomp(select(data, where(is.numeric)), scale. = TRUE)
          pca_df <- as.data.frame(pca_result$x[, 1:2])
          colnames(pca_df) <- c("PCA_1", "PCA_2")
          data <- cbind(data, pca_df)
        }
        if ("lda" %in% input$dimReduction) {
          showNotification("LDA is not implemented in this demo.", type = "warning")
        }
        if ("t-sne" %in% input$dimReduction) {
          showNotification("t-SNE is not implemented in this demo.", type = "warning")
        }
      }
      
      rv$featured[[input$activeDatasetFE]] <- data
      showNotification("Feature Engineering Changes Applied Successfully", type = "message")
      output$featureEngPreview <- renderDT({
        datatable(data, options = list(scrollX = TRUE, scrollY = "300px", paging = TRUE, pageLength = 10))
      })
    })
  })
  
  observeEvent(input$resetFE, {
    updateCheckboxGroupInput(session, "mathTransform", selected = character(0))
    updateNumericInput(session, "numCustom", value = 0)
    output$customColUI <- renderUI({ NULL })
    updateNumericInput(session, "numRename", value = 0)
    output$renameUI <- renderUI({ NULL })
    updateCheckboxInput(session, "extractTimeFeatures", value = FALSE)
    updateCheckboxInput(session, "extractTextFeatures", value = FALSE)
    updateCheckboxInput(session, "generateStats", value = FALSE)
    updateCheckboxGroupInput(session, "featureSelection", selected = character(0))
    updateCheckboxGroupInput(session, "dimReduction", selected = character(0))
    showNotification("Feature Engineering inputs reset", type = "message")
  })
  
  # ----- Exploratory Data Analysis ----- #
  observeEvent(input$activeDatasetEDA, {
    safeRun({
      req(input$activeDatasetEDA)
      data <- if (isTRUE(input$includeFE) && !is.null(rv$featured[[input$activeDatasetEDA]])) {
        rv$featured[[input$activeDatasetEDA]]
      } else {
        rv$cleaned[[input$activeDatasetEDA]]
      }
      updateSelectInput(session, "histVar", choices = names(data))
      updateSelectInput(session, "boxVars", choices = names(data))
      updateSelectInput(session, "barVars", choices = names(data))
      num_cols <- names(data)[sapply(data, is.numeric)]
      updateSelectInput(session, "scatterX", choices = num_cols)
      updateSelectInput(session, "scatterY", choices = num_cols)
      updateSelectInput(session, "colorVar", choices = c("None", names(data)), selected = "None")
    })
  })
  
  observe({
    safeRun({
      req(input$activeDatasetEDA, input$histVar)
      data <- if (isTRUE(input$includeFE) && !is.null(rv$featured[[input$activeDatasetEDA]])) {
        rv$featured[[input$activeDatasetEDA]]
      } else {
        rv$cleaned[[input$activeDatasetEDA]]
      }
      if (is.numeric(data[[input$histVar]])) {
        min_val <- min(data[[input$histVar]], na.rm = TRUE)
        max_val <- max(data[[input$histVar]], na.rm = TRUE)
        updateSliderInput(session, "filterRange", min = min_val, max = max_val, value = c(min_val, max_val))
      }
    })
  })
  
  observeEvent(input$plotData, {
    safeRun({
      req(input$plotType)
      data <- if (isTRUE(input$includeFE) && !is.null(rv$featured[[input$activeDatasetEDA]])) {
        rv$featured[[input$activeDatasetEDA]]
      } else {
        rv$cleaned[[input$activeDatasetEDA]]
      }
      if (input$plotType == "hist") {
        req(input$histVar)
        filtered_data <- data %>% filter(between(!!sym(input$histVar), input$filterRange[1], input$filterRange[2]))
        p <- ggplot(filtered_data, aes_string(x = input$histVar)) +
          geom_histogram(alpha = input$alpha, fill = "blue", bins = 30) +
          labs(title = paste("Histogram of", input$histVar))
        output$edaPlot <- renderPlotly({ ggplotly(p) })
      } else if (input$plotType == "boxplot") {
        req(input$boxVars)
        df <- data[, input$boxVars, drop = FALSE]
        df_melt <- melt(df)
        p <- ggplot(df_melt, aes(x = variable, y = value, fill = variable)) +
          geom_boxplot(alpha = input$alpha) +
          labs(title = "Boxplot")
        output$edaPlot <- renderPlotly({ ggplotly(p) })
      } else if (input$plotType == "bar") {
        req(input$barVars)
        df <- data[, input$barVars, drop = FALSE]
        df_melt <- melt(df)
        p <- ggplot(df_melt, aes(x = value, fill = variable)) +
          geom_bar(alpha = input$alpha, position = "dodge") +
          labs(title = "Bar Chart")
        output$edaPlot <- renderPlotly({ ggplotly(p) })
      } else if (input$plotType == "scatter") {
        req(input$scatterX, input$scatterY)
        filtered_data <- data %>% filter(between(!!sym(input$scatterX), input$filterRange[1], input$filterRange[2]))
        p <- ggplot(filtered_data, aes_string(x = input$scatterX, y = input$scatterY,
                                              color = if (input$colorVar != "None") input$colorVar else NULL)) +
          geom_point(alpha = input$alpha) +
          geom_smooth(method = "lm", se = FALSE) +
          labs(title = paste("Scatter Plot of", input$scatterX, "vs", input$scatterY))
        output$edaPlot <- renderPlotly({ ggplotly(p) })
      } else if (input$plotType == "heatmap") {
        corr_matrix <- cor(select(data, where(is.numeric)), use = "pairwise.complete.obs")
        output$heatmapPlot <- renderPlot({
          ggcorrplot::ggcorrplot(corr_matrix, lab = TRUE, outline.color = "white")
        })
      }
      output$statsSummary <- renderPrint({
        summary(data)
      })
    })
  })
  
  # ----- Download & Reset ----- #
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("processed_data_", input$activeDatasetDL, "_", Sys.Date(), 
            switch(input$downloadFormat,
                   "CSV" = ".csv",
                   "Excel" = ".xlsx",
                   "RDS" = ".rds"), sep = "")
    },
    content = function(file) {
      safeRun({
        data_to_download <- if (!is.null(rv$featured[[input$activeDatasetDL]])) {
          rv$featured[[input$activeDatasetDL]]
        } else if (!is.null(rv$cleaned[[input$activeDatasetDL]])) {
          rv$cleaned[[input$activeDatasetDL]]
        } else {
          rv$datasets[[input$activeDatasetDL]]
        }
        req(data_to_download)
        switch(input$downloadFormat,
               "CSV" = write.csv(data_to_download, file, row.names = FALSE),
               "Excel" = write.xlsx(data_to_download, file),
               "RDS" = saveRDS(data_to_download, file)
        )
      })
    }
  )
  
  output$downloadReport <- downloadHandler(
    filename = function() {
      paste("analysis_report_", Sys.Date(), 
            switch(input$reportFormat,
                   "HTML" = ".html",
                   "PDF" = ".pdf"), sep = "")
    },
    content = function(file) {
      safeRun({
        # Assumes a report.Rmd file exists in your working directory.
        tempReport <- file.path(tempdir(), "report.Rmd")
        file.copy("report.Rmd", tempReport, overwrite = TRUE)
        params <- list(data = rv$featured[[input$activeDatasetDL]])
        rmarkdown::render(tempReport, output_file = file, params = params, envir = new.env(parent = globalenv()))
      })
    }
  )
  
  observeEvent(input$reset, {
    safeRun({
      session$reload()
    })
  })
  
  observeEvent(input$resetApp, {
    safeRun({
      session$reload()
    })
  })
}

# ----------------------- Run the Application ----------------------- #
shinyApp(ui, server)
