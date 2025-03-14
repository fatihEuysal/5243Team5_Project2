# 5243project2_team5: Data Explorer & Comparison Tool

## Project Overview
This project is a comprehensive web application built using R's **Shiny** framework. It streamlines the data analysis workflow by consolidating critical tasks into an interactive platform. The application covers **data upload**, **cleaning & preprocessing**, **feature engineering**, **exploratory data analysis (EDA)**, as well as **downloading** the processed data. It also supports both **uploading files** from the user’s local system and selecting **built-in datasets** for immediate exploration.

### Main Functional Tabs
1. **User Guide**  
   Provides an overview of how to use this Shiny application, detailing each tab’s functionality.

2. **Data Upload**  
   - **Data Source**: Choose between uploading files (`.csv`, `.xlsx`, `.json`, `.rds`) or selecting built-in R datasets (e.g., `mtcars`, `iris`, `ToothGrowth`).  
   - **Dataset Preview**: Preview the loaded datasets to confirm successful import.

3. **Data Cleaning & Preprocessing**  
   - **Remove Duplicates**  
   - **Handle Missing Values** (remove rows, impute with mean/median/mode/KNN)  
   - **Outlier Treatment** (Z-score or IQR-based removal/imputation)  
   - **Normalization & Standardization** of numeric columns  
   - **Categorical Encoding** of character columns  
   - **Convert “numeric-like” characters** to numeric  
   - **Remove or Select Columns** dynamically  
   - **Rounding** numeric data to specified decimal places  

4. **Feature Engineering**  
   - **Mathematical Transformations**: Log, Square Root, Square, Box-Cox, Power  
   - **Additional Feature Creation**:  
     - Extract time features (year, month, day, weekday) from date columns  
     - Extract text features (word count, character count) from text columns  
     - Generate statistical features (mean, variance, median, min, max) for numeric columns  
   - **Feature Selection**:  
     - Variance Threshold  
     - Correlation Analysis  
     - Lasso (using last categorical column as target by default)  
   - **Dimensionality Reduction**: PCA, LDA  
   - **Remove or Select Columns** again after transformations  

5. **Exploratory Data Analysis (EDA)**  
   - **Plot Types**: Histogram, Bar Chart, Boxplot, Scatter Plot, Correlation Heatmap  
   - **Interactive Plots** using **plotly** (except Heatmap, which is a static plot)  
   - **Statistical Summary** of numeric columns (min, max, quartiles, mean, standard deviation)  

6. **Download & Reset**  
   - **Download Processed Data** in `.xlsx`, `.csv`, `.json`, or `.rds` formats  
   - **Reset App** to clear all uploaded and processed datasets  

---

## Collaborators
- Wenbo Liu ( Wenbo0528 )  
- Fatih Euysal ( fatihEuysal )  
- Xiaoying Wang ( XiaoyingWang412 )  
- Julieta Caroppo ( julieta87 )

---

## Code & Tools Used
- **Programming Language**: R  
- **Core Shiny App**: [data_explorer_app_final.R](./data_explorer_app_final.R)

**Required R Packages** (install them before running the app):
- shiny  
- shinyjs  
- shinythemes  
- DT  
- dplyr  
- openxlsx  
- stringr  
- readr  
- readxl  
- jsonlite  
- ggplot2  
- plotly  
- lubridate  
- ggcorrplot  
- recipes  
- caret  
- reshape2  
- MASS  
- rmarkdown  
- DBI  
- shinyWidgets  

(If you need **KNN imputation**, install `DMwR`. For **Lasso** feature selection, install `glmnet`.)

---

## Instructions
1. **Clone or download** this repository to your local machine.
2. Ensure all **required packages** are installed (see above).
3. Open the **data_explorer_app_final.R** file in RStudio (or your preferred environment).
4. Click **Run App**. A Shiny app window will open in your browser.
5. Use the **tabs** in the Shiny app to upload data, clean/preprocess, engineer features, explore, and download your processed dataset.  
6. The **Reset App** button clears all uploaded and processed datasets to start fresh.

---

## Key Features
- **Multiple Data Source Options**  
  - Upload local files: `.csv`, `.xlsx`, `.json`, `.rds`  
  - Use built-in R datasets (e.g., `mtcars`, `iris`)

- **Comprehensive Cleaning**  
  - Remove duplicates  
  - Fill or remove missing values (mean, median, mode, KNN)  
  - Identify and handle outliers (Z-score, IQR)  
  - Rounding, normalizing, standardizing  
  - Remove columns and handle numeric-like data  

- **Powerful Feature Engineering**  
  - Log, sqrt, square, Box-Cox, and power transformations  
  - Time-based features (year, month, day, weekday)  
  - Text-based features (word count, character count)  
  - Statistical aggregations (mean, var, median, min, max)  
  - Feature selection via variance threshold, correlation, Lasso  
  - Dimensionality reduction via PCA and LDA  

- **Interactive EDA**  
  - Visualizations: histograms, boxplots, bar charts, scatter plots, correlation heatmaps  
  - Adjustable opacity and dynamic axis selection  
  - Summary statistics table  

- **Easy Export & Reset**  
  - Download cleaned/engineered data in XLSX, CSV, JSON, or RDS format  
  - Quickly reset the entire app with one click  

---

## License
This project is for educational purposes and is licensed under the **MIT License**.
