-- =========================================================
-- WORLD LAYOFFS DATASET: DATA CLEANING PROJECT
-- Description: Staging, Deduplication, Text Standardization, 
--              Source Cleanup, Industry Imputation, and 
--              Data Type Conversions
-- =========================================================

-- ---------------------------------------------------------
-- 1. STAGING TABLE CREATION
-- ---------------------------------------------------------
-- Preserve raw data by creating an identical staging table
CREATE TABLE layoffs_staging LIKE layoffs;

INSERT INTO layoffs_staging 
SELECT * FROM layoffs;


-- ---------------------------------------------------------
-- 2. DEDUPLICATION
-- ---------------------------------------------------------
-- Create layoffs_staging2 with a row_num helper column to identify duplicates
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `total_laid_off` text,
  `date` text,
  `percentage_laid_off` double DEFAULT NULL,
  `industry` text,
  `source` text,
  `stage` text,
  `funds_raised` text,
  `country` text,
  `date_added` text,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Populate staging2 with row numbers partitioned across all defining fields
INSERT INTO layoffs_staging2
SELECT *,
  ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised
  ) AS row_num
FROM layoffs_staging;

-- Delete duplicate records
DELETE FROM layoffs_staging2 
WHERE row_num > 1;


-- ---------------------------------------------------------
-- 3. TEXT STANDARDIZATION & BLANK NULLIFICATION
-- ---------------------------------------------------------
-- Trim leading/trailing whitespace and convert empty strings to NULL across all text fields
UPDATE layoffs_staging2
SET company = NULLIF(TRIM(company), ''),
    location = NULLIF(TRIM(location), ''),
    industry = NULLIF(TRIM(industry), ''),
    stage = NULLIF(TRIM(stage), ''),
    country = NULLIF(TRIM(country), ''),
    funds_raised = NULLIF(TRIM(funds_raised), ''),
    total_laid_off = NULLIF(TRIM(total_laid_off), ''),
    `source` = NULLIF(TRIM(`source`), ''),
    date_added = NULLIF(TRIM(date_added), '');

-- Clean location text formatting
UPDATE layoffs_staging2
SET location = REPLACE(location, ', Non-U.S.', '')
WHERE location LIKE '%, Non-U.S.%';

-- Standardize country names
UPDATE layoffs_staging2
SET country = 'United Arab Emirates'
WHERE country = 'UAE';


-- ---------------------------------------------------------
-- 4. SOURCE COLUMN CLEANUP & STANDARDIZATION
-- ---------------------------------------------------------
-- Standardize Company Executive variations
UPDATE layoffs_staging2
SET `source` = 'Company Executive'
WHERE LOWER(TRIM(`source`)) IN ('company exec', 'company executive');

-- Standardize Internal Memo capitalization
UPDATE layoffs_staging2
SET `source` = 'Internal Memo'
WHERE LOWER(TRIM(`source`)) = 'internal memo';

-- Nullify incomplete text artifacts
UPDATE layoffs_staging2
SET `source` = NULL
WHERE LOWER(TRIM(`source`)) = 'read more at:';

-- Fix incomplete URL path for Clockwork
UPDATE layoffs_staging2
SET `source` = 'https://techcrunch.com/2023/08/28/solana-based-automation-startup-clockwork-to-shut-down/'
WHERE `source` LIKE '%solana-based-automation-startup-clockwork%';


-- ---------------------------------------------------------
-- 5. MISSING INDUSTRY POPULATION
-- ---------------------------------------------------------
-- Populate missing industries for verified companies
UPDATE layoffs_staging2 
SET industry = 'Media' 
WHERE company = 'Eyeo';

UPDATE layoffs_staging2 
SET industry = 'Software' 
WHERE company = 'Appsmith';


-- ---------------------------------------------------------
-- 6. DATE & NUMERIC TYPE CONVERSIONS
-- ---------------------------------------------------------
-- Convert date string columns to standard SQL DATE type
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y')
WHERE `date` IS NOT NULL;

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

UPDATE layoffs_staging2
SET date_added = STR_TO_DATE(date_added, '%m/%d/%Y')
WHERE date_added IS NOT NULL;

ALTER TABLE layoffs_staging2
MODIFY COLUMN date_added DATE;

-- Clean percentage numerical values
UPDATE layoffs_staging2
SET percentage_laid_off = ROUND(percentage_laid_off, 2);

UPDATE layoffs_staging2
SET percentage_laid_off = NULL
WHERE percentage_laid_off = 0;

-- Convert numerical columns to INT
ALTER TABLE layoffs_staging2
MODIFY COLUMN total_laid_off INT,
MODIFY COLUMN funds_raised INT;


-- ---------------------------------------------------------
-- 7. CLEANUP HELPER COLUMNS
-- ---------------------------------------------------------
-- Drop the temporary deduplication column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- ---------------------------------------------------------
-- VERIFY CLEANED DATASET
-- ---------------------------------------------------------
SELECT * FROM layoffs_staging2;
