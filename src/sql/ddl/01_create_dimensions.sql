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


-----------------------------------------------------------------------------------
/* =========================================================
   DIMENSION: core.dim_customer (END-to-END)
   DB      : insurance_DB
   Source  : stg.helper_numbers
   Grain   : 1 row per customer
========================================================= */

-----------------------------------------------------------
-- 0) Safety checks (same batch)
-----------------------------------------------------------
IF DB_ID('insurance_DB') IS NULL
BEGIN
    RAISERROR('Database insurance_DB does not exist.', 16, 1);
    RETURN;
END;

USE insurance_DB;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
BEGIN
    RAISERROR('Schema core does not exist.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('stg.helper_numbers','U') IS NULL
BEGIN
    RAISERROR('Table stg.helper_numbers does not exist. Create it first.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) Parameters (change only here)
-----------------------------------------------------------
DECLARE @customer_rows INT = 1000000; -- 1,000,000 customers (change as needed)

-----------------------------------------------------------
-- 2) DDL: Drop & Create
-----------------------------------------------------------
IF OBJECT_ID('core.dim_customer','U') IS NOT NULL
    DROP TABLE core.dim_customer;

CREATE TABLE core.dim_customer (
    customer_key        BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id         VARCHAR(30)   NOT NULL,      -- business id (unique)
    first_name          VARCHAR(50)   NOT NULL,
    last_name           VARCHAR(50)   NOT NULL,
    gender              CHAR(1)       NULL,          -- M/F/O
    date_of_birth       DATE          NULL,
    email               VARCHAR(100)  NULL,
    phone               VARCHAR(20)   NULL,

    address_line1       VARCHAR(120)  NULL,
    city                VARCHAR(60)   NULL,
    state               VARCHAR(60)   NULL,
    postal_code         VARCHAR(15)   NULL,

    customer_since_date DATE          NULL,
    customer_status     VARCHAR(20)   NOT NULL DEFAULT('Active'), -- Active/Inactive
    occupation          VARCHAR(60)   NULL,

    created_at          DATETIME2(0)  NOT NULL DEFAULT(SYSDATETIME()),
    updated_at          DATETIME2(0)  NULL
);

-- Unique business key
CREATE UNIQUE INDEX UX_dim_customer_customer_id
ON core.dim_customer(customer_id);

-- Helpful analytics indexes
CREATE INDEX IX_dim_customer_state_city
ON core.dim_customer(state, city);

-----------------------------------------------------------
-- 3) DML: Load data (set-based, scalable)
-----------------------------------------------------------
;WITH n AS (
    SELECT TOP (@customer_rows) n
    FROM stg.helper_numbers
    ORDER BY n
)
INSERT INTO core.dim_customer (
    customer_id, first_name, last_name, gender, date_of_birth,
    email, phone, address_line1, city, state, postal_code,
    customer_since_date, customer_status, occupation
)
SELECT
    CONCAT('CUST', RIGHT(CONCAT('0000000000', CAST(n AS VARCHAR(10))), 10)) AS customer_id,

    CONCAT('First', RIGHT(CONCAT('000000', CAST(n % 1000000 AS VARCHAR(6))), 6)) AS first_name,
    CONCAT('Last',  RIGHT(CONCAT('000000', CAST((n * 7) % 1000000 AS VARCHAR(6))), 6)) AS last_name,

    CASE (n % 20)
        WHEN 0 THEN 'O'
        WHEN 1 THEN 'F'
        ELSE 'M'
    END AS gender,

    DATEADD(DAY, (n % 16071), CONVERT(date,'1960-01-01')) AS date_of_birth,

    CONCAT('cust', n, '@example.com') AS email,
    CONCAT('+91', RIGHT(CONCAT('0000000000', CAST((n * 97) % 10000000000 AS VARCHAR(10))), 10)) AS phone,

    CONCAT('Address Line ', (n % 5000) + 1) AS address_line1,

    CASE (n % 10)
        WHEN 0 THEN 'Mumbai'
        WHEN 1 THEN 'Pune'
        WHEN 2 THEN 'Bengaluru'
        WHEN 3 THEN 'Hyderabad'
        WHEN 4 THEN 'Delhi'
        WHEN 5 THEN 'Chennai'
        WHEN 6 THEN 'Kolkata'
        WHEN 7 THEN 'Ahmedabad'
        WHEN 8 THEN 'Jaipur'
        ELSE 'Surat'
    END AS city,

    CASE (n % 10)
        WHEN 0 THEN 'Maharashtra'
        WHEN 1 THEN 'Maharashtra'
        WHEN 2 THEN 'Karnataka'
        WHEN 3 THEN 'Telangana'
        WHEN 4 THEN 'Delhi'
        WHEN 5 THEN 'Tamil Nadu'
        WHEN 6 THEN 'West Bengal'
        WHEN 7 THEN 'Gujarat'
        WHEN 8 THEN 'Rajasthan'
        ELSE 'Gujarat'
    END AS state,

    RIGHT(CONCAT('000000', CAST((n * 13) % 1000000 AS VARCHAR(6))), 6) AS postal_code,

    DATEADD(DAY, (n % 3287), CONVERT(date,'2018-01-01')) AS customer_since_date,

    CASE WHEN (n % 50) = 0 THEN 'Inactive' ELSE 'Active' END AS customer_status,

    CASE (n % 8)
        WHEN 0 THEN 'Salaried'
        WHEN 1 THEN 'Self-Employed'
        WHEN 2 THEN 'Student'
        WHEN 3 THEN 'Retired'
        WHEN 4 THEN 'Business'
        WHEN 5 THEN 'Freelancer'
        WHEN 6 THEN 'Homemaker'
        ELSE 'Unemployed'
    END AS occupation
FROM n;

-----------------------------------------------------------
-- 4) Post-insert validations
-----------------------------------------------------------
SELECT COUNT(*) AS CustomerRowCount
FROM core.dim_customer;

SELECT TOP 10 *
FROM core.dim_customer
ORDER BY customer_key;

SELECT COUNT(*) AS DuplicateCustomerIds
FROM (
    SELECT customer_id
    FROM core.dim_customer
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d;
SELECT * from core.dim_customer