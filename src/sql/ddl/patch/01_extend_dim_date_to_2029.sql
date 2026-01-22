USE insurance_DB;

DECLARE @current_max DATE = (SELECT MAX(full_date) FROM core.dim_date);
DECLARE @new_max     DATE = '2029-12-31';

IF @current_max >= @new_max
BEGIN
    SELECT 'dim_date already covers required range' AS status, @current_max AS current_max;
    RETURN;
END;

;WITH d AS (
    SELECT TOP (DATEDIFF(DAY, DATEADD(DAY, 1, @current_max), @new_max) + 1)
           DATEADD(DAY, n - 1, DATEADD(DAY, 1, @current_max)) AS dt
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

-- Validation
SELECT
    COUNT(*) AS TotalDates,
    MIN(full_date) AS MinDate,
    MAX(full_date) AS MaxDate
FROM core.dim_date;

-- Duplicate check (must be 0)
SELECT COUNT(*) AS DuplicateDateKeys
FROM (
    SELECT date_key
    FROM core.dim_date
    GROUP BY date_key
    HAVING COUNT(*) > 1
) x;
