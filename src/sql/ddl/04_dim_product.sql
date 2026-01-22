/* =========================================================
   DIMENSION: core.dim_product (FINAL END-TO-END)
   Database : insurance_DB
   Schema   : core
   Grain    : 1 row per insurance product
   Target   : 120 products
========================================================= */

-----------------------------------------------------------
-- 0) Safety checks
-----------------------------------------------------------
IF DB_ID('insurance_DB') IS NULL
BEGIN
    RAISERROR('Database insurance_DB does not exist.', 16, 1);
    RETURN;
END;

USE insurance_DB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
BEGIN
    RAISERROR('Schema core does not exist.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) DDL: Drop & Create
-----------------------------------------------------------
IF OBJECT_ID('core.dim_product','U') IS NOT NULL
    DROP TABLE core.dim_product;

CREATE TABLE core.dim_product (
    product_key       INT IDENTITY(1,1) PRIMARY KEY,
    product_id        VARCHAR(30) NOT NULL,
    product_code      VARCHAR(30) NOT NULL,
    product_name      VARCHAR(120) NOT NULL,

    product_line      VARCHAR(30) NOT NULL,
    product_type      VARCHAR(40) NOT NULL,
    coverage_level    VARCHAR(20) NOT NULL,
    is_addon_allowed  BIT NOT NULL,

    base_premium_min  DECIMAL(12,2) NOT NULL,
    base_premium_max  DECIMAL(12,2) NOT NULL,
    sum_insured_min   DECIMAL(14,2) NOT NULL,
    sum_insured_max   DECIMAL(14,2) NOT NULL,

    is_active         BIT NOT NULL,
    created_at        DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    updated_at        DATETIME2(0) NULL
);

CREATE UNIQUE INDEX UX_dim_product_product_id
ON core.dim_product(product_id);

CREATE UNIQUE INDEX UX_dim_product_product_code
ON core.dim_product(product_code);

-----------------------------------------------------------
-- 2) DML: Insert 120 deterministic products
-----------------------------------------------------------
INSERT INTO core.dim_product (
    product_id, product_code, product_name,
    product_line, product_type, coverage_level,
    is_addon_allowed,
    base_premium_min, base_premium_max,
    sum_insured_min, sum_insured_max,
    is_active
)
SELECT
    CONCAT('PRD', RIGHT('0000' + CAST(h.n AS VARCHAR(4)), 4)),
    CONCAT('PC',  RIGHT('0000' + CAST(h.n AS VARCHAR(4)), 4)),

    CONCAT(pl.product_line, ' - ', pt.product_type, ' (', cv.coverage_level, ')'),

    pl.product_line,
    pt.product_type,
    cv.coverage_level,

    CASE
        WHEN cv.coverage_level = 'Premium' THEN 1
        WHEN pt.product_type IN ('ThirdParty') THEN 0
        ELSE 1
    END AS is_addon_allowed,

    bp.base_premium_min,
    bp.base_premium_max,
    si.sum_insured_min,
    si.sum_insured_max,

    CASE WHEN h.n % 20 = 0 THEN 0 ELSE 1 END
FROM (
    SELECT TOP (120) n
    FROM stg.helper_numbers
    ORDER BY n
) h
CROSS APPLY (
    SELECT CASE
        WHEN h.n BETWEEN 1  AND 42 THEN 'Motor'
        WHEN h.n BETWEEN 43 AND 72 THEN 'Health'
        WHEN h.n BETWEEN 73 AND 90 THEN 'Life'
        WHEN h.n BETWEEN 91 AND 102 THEN 'Home'
        WHEN h.n BETWEEN 103 AND 112 THEN 'Travel'
        ELSE 'SME'
    END AS product_line
) pl
CROSS APPLY (
    SELECT CASE pl.product_line
        WHEN 'Motor'  THEN CASE WHEN h.n % 2 = 0 THEN 'Comprehensive' ELSE 'ThirdParty' END
        WHEN 'Health' THEN CASE WHEN h.n % 2 = 0 THEN 'FamilyFloater' ELSE 'Individual' END
        WHEN 'Life'   THEN CASE WHEN h.n % 2 = 0 THEN 'Term' ELSE 'Endowment' END
        WHEN 'Home'   THEN CASE WHEN h.n % 2 = 0 THEN 'Structure' ELSE 'Structure+Contents' END
        WHEN 'Travel' THEN CASE WHEN h.n % 2 = 0 THEN 'SingleTrip' ELSE 'MultiTrip' END
        ELSE               CASE WHEN h.n % 2 = 0 THEN 'Liability' ELSE 'Property' END
    END AS product_type
) pt
CROSS APPLY (
    SELECT CASE h.n % 3
        WHEN 0 THEN 'Basic'
        WHEN 1 THEN 'Standard'
        ELSE 'Premium'
    END AS coverage_level
) cv
CROSS APPLY (
    SELECT
        CASE pl.product_line
            WHEN 'Motor'  THEN 2000
            WHEN 'Health' THEN 3000
            WHEN 'Life'   THEN 5000
            WHEN 'Home'   THEN 1500
            WHEN 'Travel' THEN 500
            ELSE 8000
        END AS base_premium_min,
        CASE pl.product_line
            WHEN 'Motor'  THEN 20000
            WHEN 'Health' THEN 30000
            WHEN 'Life'   THEN 50000
            WHEN 'Home'   THEN 15000
            WHEN 'Travel' THEN 5000
            ELSE 100000
        END AS base_premium_max
) bp
CROSS APPLY (
    SELECT
        CASE pl.product_line
            WHEN 'Motor'  THEN 100000
            WHEN 'Health' THEN 200000
            WHEN 'Life'   THEN 500000
            WHEN 'Home'   THEN 300000
            WHEN 'Travel' THEN 50000
            ELSE 1000000
        END AS sum_insured_min,
        CASE pl.product_line
            WHEN 'Motor'  THEN 1000000
            WHEN 'Health' THEN 2000000
            WHEN 'Life'   THEN 10000000
            WHEN 'Home'   THEN 3000000
            WHEN 'Travel' THEN 500000
            ELSE 50000000
        END AS sum_insured_max
) si;

-----------------------------------------------------------
-- 3) Post-insert validations
-----------------------------------------------------------

-- Row count
SELECT COUNT(*) AS ProductRowCount
FROM core.dim_product;

-- Column count
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_product');

-- Duplicate checks
SELECT COUNT(*) AS DuplicateProductIds
FROM (
    SELECT product_id FROM core.dim_product
    GROUP BY product_id HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS DuplicateProductCodes
FROM (
    SELECT product_code FROM core.dim_product
    GROUP BY product_code HAVING COUNT(*) > 1
) d;

-- Distribution checks
SELECT product_line, COUNT(*) AS cnt
FROM core.dim_product
GROUP BY product_line
ORDER BY cnt DESC;

SELECT coverage_level, COUNT(*) AS cnt
FROM core.dim_product
GROUP BY coverage_level;

SELECT is_active, COUNT(*) AS cnt
FROM core.dim_product
GROUP BY is_active;

-- Preview
SELECT TOP 10 *
FROM core.dim_product
ORDER BY product_key;
