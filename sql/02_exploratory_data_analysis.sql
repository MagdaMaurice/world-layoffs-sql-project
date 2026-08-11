-- =========================================================
-- WORLD LAYOFFS DATASET: EXPLORATORY DATA ANALYSIS (EDA)
-- Description: Uncovering trends, company impacts, industry 
--              breakdowns, temporal trajectory, stage shutdowns, 
--              and reporting latency.
-- =========================================================

-- ---------------------------------------------------------
-- 1. OVERVIEW & BASELINE METRICS
-- ---------------------------------------------------------
-- Full dataset view
SELECT * 
FROM layoffs_staging2;

-- Maximum scale of layoffs and percentage impact
SELECT 
    MAX(total_laid_off) AS max_single_layoff, 
    MAX(percentage_laid_off) AS max_percentage_laid_off
FROM layoffs_staging2;

-- Companies that completely shut down (100% laid off) ordered by capital raised
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised DESC;

-- Timeline scope of the dataset
SELECT 
    MIN(`date`) AS earliest_layoff, 
    MAX(`date`) AS latest_layoff
FROM layoffs_staging2;


-- ---------------------------------------------------------
-- 2. AGGREGATE SUMMARIES (BY CATEGORY)
-- ---------------------------------------------------------
-- Total workforce impact by company
SELECT 
    company, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company
ORDER BY total_laid_off DESC;

-- Total workforce impact by industry
SELECT 
    industry, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_laid_off DESC;

-- Total workforce impact by country
SELECT 
    country, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY country
ORDER BY total_laid_off DESC;

-- Total workforce impact by funding stage
SELECT 
    stage, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY stage
ORDER BY total_laid_off DESC;

-- Average percentage laid off per company
SELECT 
    company, 
    ROUND(AVG(percentage_laid_off), 2) AS avg_percentage_laid_off
FROM layoffs_staging2
GROUP BY company
ORDER BY avg_percentage_laid_off DESC;


-- ---------------------------------------------------------
-- 3. TEMPORAL TRENDS & ROLLING TOTALS
-- ---------------------------------------------------------
-- Total workforce impact by year
SELECT 
    YEAR(`date`) AS `year`, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY `year` DESC;

-- Seasonal monthly breakdown (Combining all Januaries, Februaries, etc.)
SELECT 
    MONTH(`date`) AS `month_number`,
    DATE_FORMAT(`date`, '%M') AS `month_name`,
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY `month_number`, `month_name`
ORDER BY `month_number` ASC;

-- Monthly trend analysis
SELECT 
    DATE_FORMAT(`date`, '%Y-%m') AS `year_month`, 
    SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL 
  AND total_laid_off IS NOT NULL
GROUP BY `year_month`
ORDER BY `year_month` ASC;

-- Cumulative rolling total of layoffs over time
WITH Monthly_Totals AS (
    SELECT 
        DATE_FORMAT(`date`, '%Y-%m') AS `year_month`, 
        SUM(total_laid_off) AS total_off
    FROM layoffs_staging2
    WHERE `date` IS NOT NULL
      AND total_laid_off IS NOT NULL
    GROUP BY `year_month`
)
SELECT 
    `year_month`, 
    total_off,
    SUM(total_off) OVER(ORDER BY `year_month`) AS rolling_total_layoffs
FROM Monthly_Totals
ORDER BY `year_month` ASC;


-- ---------------------------------------------------------
-- 4. YEARLY RANKINGS (TOP 5 COMPANIES PER YEAR)
-- ---------------------------------------------------------
-- Rank companies by total layoffs within each year using Window Functions
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
SELECT 
    `year`,
    ranking,
    company,
    total_laid_off
FROM Company_Year_Rank
WHERE ranking <= 5
ORDER BY `year` DESC, ranking ASC;


-- ---------------------------------------------------------
-- 5. STAGE ANALYSIS & COMPLETE SHUTDOWNS
-- ---------------------------------------------------------
-- Analyze event volume, layoff size, averages, and complete shutdowns (100% laid off) by stage
WITH Stage_Shutdowns AS (
    SELECT 
        stage, 
        COUNT(*) AS total_layoff_events, 
        SUM(total_laid_off) AS total_laid_off,
        ROUND(AVG(percentage_laid_off), 2) AS avg_percentage_laid_off,
        SUM(CASE WHEN percentage_laid_off = 1 THEN 1 ELSE 0 END) AS total_complete_shutdowns
    FROM layoffs_staging2
    WHERE stage IS NOT NULL
      AND stage != 'unknown'
    GROUP BY stage
)
SELECT 
    stage,
    total_layoff_events,
    total_laid_off,
    avg_percentage_laid_off,
    total_complete_shutdowns,
    DENSE_RANK() OVER(ORDER BY total_complete_shutdowns DESC) AS shutdown_rank
FROM Stage_Shutdowns
ORDER BY shutdown_rank ASC;


-- ---------------------------------------------------------
-- 6. REPORTING LATENCY & BACKFILL SPEED ANALYSIS
-- ---------------------------------------------------------
-- Categorize time gap between actual layoff date and entry date_added
WITH Reporting_Latency AS (
    SELECT 
        company, 
        stage, 
        total_laid_off, 
        `date` AS layoff_date, 
        date_added,
        DATEDIFF(date_added, `date`) AS delay_in_days
    FROM layoffs_staging2
    WHERE `date` IS NOT NULL
      AND date_added IS NOT NULL
)
SELECT 
    company, 
    stage, 
    total_laid_off, 
    layoff_date, 
    date_added, 
    delay_in_days,
    CASE
        WHEN delay_in_days = 0 THEN 'Same day report'
        WHEN delay_in_days BETWEEN 1 AND 7 THEN 'Within 1 week'
        WHEN delay_in_days BETWEEN 8 AND 30 THEN 'Within 1 month'
        WHEN delay_in_days BETWEEN 31 AND 365 THEN '1 month to 1 year (backfilled)'
        ELSE 'Over 1 year (historical backfill)'
    END AS reporting_speed_category
FROM Reporting_Latency
WHERE delay_in_days >= 0
ORDER BY delay_in_days DESC;
