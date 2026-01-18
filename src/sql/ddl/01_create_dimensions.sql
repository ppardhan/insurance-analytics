/* =========================================================
   DIMENSION: core.dim_date (END-to-END)
   DB      : insurance_DB
   Source  : stg.helper_numbers
   Range   : 2018-01-01 to 2026-12-31
========================================================= */

-----------------------------------------------------------
-- 0) Safety checks
-----------------------------------------------------------
IF DB_ID('insurance_DB') IS NULL
BEGIN
    RAISERROR('Database insurance_DB does not exist.', 16, 1);
    RETURN;
END
GO

USE insurance_DB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
BEGIN
    RAISERROR('Schema core does not exist.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('stg.helper_numbers','U') IS NULL
BEGIN
    RAISERROR('Table stg.helper_numbers does not exist. Create it before dim_date.', 16, 1);
    RETURN;
END
GO

-----------------------------------------------------------
-- 1) Create table (drop & recreate)
-----------------------------------------------------------
IF OBJECT_ID('core.dim_date','U') IS NOT NULL
    DROP TABLE core.dim_date;
GO

CREATE TABLE core.dim_date(
  date_key        INT          NOT NULL PRIMARY KEY,  -- yyyymmdd
  full_date       DATE         NOT NULL,
  [year]          SMALLINT     NOT NULL,
  [quarter]       TINYINT      NOT NULL,
  month_no        TINYINT      NOT NULL,
  month_name      VARCHAR(10)  NOT NULL,
  day_of_month    TINYINT      NOT NULL,
  day_name        VARCHAR(10)  NOT NULL,
  week_of_year    TINYINT      NOT NULL,
  is_month_end    BIT          NOT NULL,
  is_weekend      BIT          NOT NULL
);
GO

-----------------------------------------------------------
-- 2) Load data
-----------------------------------------------------------
DECLARE @start DATE='2018-01-01', @end DATE='2026-12-31';

;WITH d AS (
  SELECT TOP (DATEDIFF(DAY,@start,@end)+1)
    DATEADD(DAY, n-1, @start) AS dt
  FROM stg.helper_numbers
  ORDER BY n
)
INSERT INTO core.dim_date (
  date_key, full_date, [year], [quarter], month_no, month_name,
  day_of_month, day_name, week_of_year, is_month_end, is_weekend
)
SELECT
  CONVERT(INT, FORMAT(dt,'yyyyMMdd')) AS date_key,
  dt,
  YEAR(dt),
  DATEPART(QUARTER, dt),
  MONTH(dt),
  DATENAME(MONTH, dt),
  DAY(dt),
  DATENAME(WEEKDAY, dt),
  DATEPART(WEEK, dt),
  CASE WHEN EOMONTH(dt)=dt THEN 1 ELSE 0 END,
  CASE WHEN DATENAME(WEEKDAY,dt) IN ('Saturday','Sunday') THEN 1 ELSE 0 END
FROM d;
GO

-----------------------------------------------------------
-- 3) Validation (must pass)
-----------------------------------------------------------

-- Row count
SELECT COUNT(*) AS TotalDates
FROM core.dim_date;

-- Min/Max range
SELECT MIN(full_date) AS MinDate, MAX(full_date) AS MaxDate
FROM core.dim_date;

-- Duplicate keys (should be 0)
SELECT COUNT(*) AS DuplicateKeys
FROM (
    SELECT date_key
    FROM core.dim_date
    GROUP BY date_key
    HAVING COUNT(*) > 1
) d;

-- Preview
SELECT TOP 10 *
FROM core.dim_date
ORDER BY date_key;
GO
