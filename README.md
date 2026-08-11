# world-layoffs-sql-project
End-to-end SQL project transforming raw global layoff data through a multi-stage data cleaning pipeline and exploratory data analysis (EDA) in MySQL.
# World Layoffs Data Cleaning & Exploratory Data Analysis (SQL)

An end-to-end data engineering and analytics project built with MySQL. This repository demonstrates how to transform raw, unformatted global layoff data into a production-ready analytical dataset, followed by an in-depth Exploratory Data Analysis (EDA) to uncover macroeconomic trends, high-risk funding stages, corporate impacts, and reporting latency patterns.

---

## Executive Summary

The **World Layoffs Dataset** contains raw data on workforce reduction events reported globally. Raw datasets often suffer from duplicate records, inconsistent categorical labels, improperly typed date fields, and incomplete source attributes.

This project delivers a two-stage SQL solution:
1. **`01_data_cleaning.sql`**: A data cleaning pipeline that preserves raw data integrity, deduplicates records, standardizes text formatting, fixes dirty source labels, populates missing industries, and enforces strong database schema typing.
2. **`02_exploratory_data_analysis.sql`**: An exploratory framework utilizing MySQL window functions, CTEs, and temporal aggregations to quantify total workforce impact across industries, funding stages, time periods, and corporate reporting speeds.

---

## Repository Structure

| File | Description |
| :--- | :--- |
| **`sql/01_data_cleaning.sql`** | SQL pipeline for staging, deduplication, text normalization, source cleanup, and schema enforcement. |
| **`sql/02_exploratory_data_analysis.sql`** | SQL analytical script covering baseline metrics, temporal trends, yearly rankings, stage shutdowns, and latency tracking. |
| **`layoffs.csv`** | Raw dataset containing global layoff events. |
| **`README.md`** | Comprehensive project documentation and insights guide. |

---

## Data Cleaning Pipeline (`01_data_cleaning.sql`)

The data cleaning pipeline adheres to production ETL practices by isolating raw data inside staging environments before executing multi-phase transformations:

```
[Raw Data: layoffs] 
       │
       ▼
[Staging Table 1: layoffs_staging]  ── (Preserves raw original state)
       │
       ▼
[Staging Table 2: layoffs_staging2] ── (Executes Deduplication, Standardization & Typing)
```

### Key Cleaning Steps

#### 1. Staging & Preserving Data Integrity
Raw data is loaded into `layoffs_staging`, while structural transformations are applied inside `layoffs_staging2` to ensure raw data can always be audited or recovered.

#### 2. Deduplication via Window Functions
Identical records are identified across all key defining fields (`company`, `location`, `industry`, `total_laid_off`, `percentage_laid_off`, `date`, `stage`, `country`, `funds_raised`) using `ROW_NUMBER() OVER (...)`. All rows with `row_num > 1` are permanently removed.

```sql
DELETE FROM layoffs_staging2 
WHERE row_num > 1;
```

#### 3. Text Normalization & Blank Nullification
* Whitespace is stripped across all string columns using `TRIM()`.
* Blank string values (`''`) are converted to database `NULL` values via `NULLIF()`.
* Location strings containing redundant qualifiers (e.g., `, Non-U.S.`) are cleaned using `REPLACE()`.
* Country names are standardized (e.g., `UAE` → `United Arab Emirates`).

#### 4. Source Attribute Cleanup
Categorical values in the `source` column contained typos, non-URL strings, and trailing whitespace. Case-insensitive normalization using `LOWER(TRIM())` and array matching using `IN (...)` standardizes these attributes:
* Variations like `'Company exec'` and `'Company executive'` are consolidated into `'Company Executive'`.
* Incomplete text artifacts such as `'Read more at:'` are converted to `NULL`.
* Partial URL strings (e.g., Clockwork shutdown notice) are repaired to full valid URLs.

#### 5. Industry Imputation
Known industry information was verified and imputed for companies with missing records (e.g., populating `Media` for `Eyeo` and `Software` for `Appsmith`).

#### 6. Schema Typing & Date Casting
Date attributes stored as strings (`MM/DD/YYYY`) are parsed using `STR_TO_DATE()` and cast to standard MySQL `DATE` types. Integer metrics (`total_laid_off`, `funds_raised`) are cast to `INT`, and percentages are rounded to two decimal places.

---

## Exploratory Data Analysis (`02_exploratory_data_analysis.sql`)

The exploratory analysis investigates the cleaned dataset across five key dimensions:

### 1. Macro Temporal Trends & Rolling Totals
Tracks total monthly layoff volume alongside a cumulative rolling total using window functions (`SUM() OVER(...)`). This reveals acceleration phases in tech and corporate downsizing across time.

```sql
WITH Monthly_Totals AS (
    SELECT 
        DATE_FORMAT(`date`, '%Y-%m') AS `year_month`, 
        SUM(total_laid_off) AS total_off
    FROM layoffs_staging2
    WHERE `date` IS NOT NULL AND total_laid_off IS NOT NULL
    GROUP BY `year_month`
)
SELECT 
    `year_month`, 
    total_off,
    SUM(total_off) OVER(ORDER BY `year_month`) AS rolling_total_layoffs
FROM Monthly_Totals
ORDER BY `year_month` ASC;
```

### 2. Corporate & Industry Breakdown
Aggregates total layoffs across companies, industries, countries, and funding stages to isolate where job losses were concentrated globally.

### 3. Yearly Company Rankings
Utilizes CTEs and `DENSE_RANK() OVER (PARTITION BY year ORDER BY total_laid_off DESC)` to construct a leaderboard of the top 5 companies with the largest workforce reductions per calendar year.

```sql
WITH Company_Year AS (
    SELECT 
        company, 
        YEAR(`date`) AS `year`, 
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging2
    WHERE `date` IS NOT NULL
    GROUP BY company, YEAR(`date`)
),
Company_Year_Rank AS (
    SELECT 
        company,
        `year`,
        total_laid_off,
        DENSE_RANK() OVER(PARTITION BY `year` ORDER BY total_laid_off DESC) AS ranking
    FROM Company_Year
)
SELECT * FROM Company_Year_Rank
WHERE ranking <= 5
ORDER BY `year` DESC, ranking ASC;
```

### 4. Funding Stage Vulnerability & Complete Shutdowns
Analyzes total layoff events, average percentage laid off, and complete company closures (`percentage_laid_off = 1.0`) categorized by startup funding stage (e.g., Seed, Series A–J, Post-IPO).

### 5. Reporting Latency Analysis
Calculates the time lag in days between the actual layoff event date (`date`) and the entry addition date (`date_added`) using `DATEDIFF()`. Categorizes events into speed buckets (*Same day*, *Within 1 week*, *Within 1 month*, *Historical backfill*) to measure news delivery speed and dataset latency.

---

## SQL Concepts & Tech Stack

* **Database Management System:** MySQL 8.0+
* **Window Functions:** `ROW_NUMBER()`, `DENSE_RANK()`, `SUM() OVER()`
* **Common Table Expressions (CTEs):** Multi-level CTEs for layered ranking and rolling aggregation
* **Data Cleaning Functions:** `TRIM()`, `NULLIF()`, `REPLACE()`, `LOWER()`, `CASE WHEN`
* **Date & Time Operations:** `STR_TO_DATE()`, `DATE_FORMAT()`, `DATEDIFF()`, `YEAR()`, `MONTH()`
* **Data Definition Language (DDL):** `CREATE TABLE LIKE`, `ALTER TABLE MODIFY COLUMN`, `DROP COLUMN`

---

## How to Run This Project

### Prerequisites
* MySQL Server 8.0 or higher
* MySQL Workbench, DBeaver, or MySQL CLI

### Execution Steps
1. **Clone the repository or download the project files.**
2. **Create database & import raw data:**
   Import `layoffs.csv` into a MySQL database named `world_layoffs` into a table named `layoffs`.
3. **Run Data Cleaning Script:**
   Execute `01_data_cleaning.sql` in your SQL client. This will build `layoffs_staging2` and clean all records.
4. **Run Exploratory Data Analysis Script:**
   Execute `02_exploratory_data_analysis.sql` to run all analytical queries against the cleaned dataset.
