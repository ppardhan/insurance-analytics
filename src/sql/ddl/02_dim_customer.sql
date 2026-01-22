/* =========================================================
   DIMENSION: core.dim_customer (FINAL END-to-END)
   Database : insurance_DB
   Schema   : core
   Source   : stg.helper_numbers
   Grain    : 1 row per customer
   Target   : 2,000,000 customers
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
GO   -- only GO before variable declaration

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
BEGIN
    RAISERROR('Schema core does not exist.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('stg.helper_numbers','U') IS NULL
BEGIN
    RAISERROR('Table stg.helper_numbers does not exist.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) Parameters (NO GO after this)
-----------------------------------------------------------
DECLARE @customer_rows INT = 2000000;   -- LOCKED requirement

-----------------------------------------------------------
-- 2) DDL: Drop & Create table
-----------------------------------------------------------
IF OBJECT_ID('core.dim_customer','U') IS NOT NULL
    DROP TABLE core.dim_customer;

CREATE TABLE core.dim_customer (
    customer_key        BIGINT       IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id         VARCHAR(30)   NOT NULL,      -- business key
    first_name          VARCHAR(50)   NOT NULL,
    last_name           VARCHAR(50)   NOT NULL,
    gender              CHAR(1)       NULL,          -- M / F / O
    date_of_birth       DATE          NULL,
    email               VARCHAR(100)  NULL,
    phone               VARCHAR(20)   NULL,

    address_line1       VARCHAR(120)  NULL,
    city                VARCHAR(60)   NULL,
    state               VARCHAR(60)   NULL,
    postal_code         VARCHAR(15)   NULL,

    customer_since_date DATE          NULL,
    customer_status     VARCHAR(20)   NOT NULL,
    occupation          VARCHAR(60)   NOT NULL,

    created_at          DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    updated_at          DATETIME2(0)  NULL
);

CREATE UNIQUE INDEX UX_dim_customer_customer_id
ON core.dim_customer(customer_id);

CREATE INDEX IX_dim_customer_state_city
ON core.dim_customer(state, city);

-----------------------------------------------------------
-- 3) DML: Load data (realistic industry distribution)
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
    CONCAT('CUST', RIGHT('0000000000' + CAST(n AS VARCHAR(10)), 10)),

    CONCAT('First', RIGHT('000000' + CAST(n % 1000000 AS VARCHAR(6)), 6)),
    CONCAT('Last',  RIGHT('000000' + CAST((n * 7) % 1000000 AS VARCHAR(6)), 6)),

    -- Gender (≈90% M, 5% F, 5% O)
    CASE (n % 20)
        WHEN 0 THEN 'O'
        WHEN 1 THEN 'F'
        ELSE 'M'
    END,

    -- DOB between 1960–2003
    DATEADD(DAY, (n % 16071), '1960-01-01'),

    CONCAT('cust', n, '@example.com'),
    CONCAT('+91', RIGHT('0000000000' + CAST((n * 97) % 10000000000 AS VARCHAR(10)), 10)),

    CONCAT('Address Line ', (n % 5000) + 1),

    -- City
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
    END,

    -- State
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
    END,

    RIGHT('000000' + CAST((n * 13) % 1000000 AS VARCHAR(6)), 6),

    -- Customer since 2018–2026
    DATEADD(DAY, (n % 3287), '2018-01-01'),

    -- Status (≈2% inactive)
    CASE WHEN (n % 50) = 0 THEN 'Inactive' ELSE 'Active' END,

    -- Occupation (REALISTIC INSURANCE DISTRIBUTION)
    CASE
        WHEN (n % 100) BETWEEN 0  AND 44 THEN 'Salaried'        -- 45%
        WHEN (n % 100) BETWEEN 45 AND 64 THEN 'Self-Employed'  -- 20%
        WHEN (n % 100) BETWEEN 65 AND 79 THEN 'Business'       -- 15%
        WHEN (n % 100) BETWEEN 80 AND 86 THEN 'Student'        -- 7%
        WHEN (n % 100) BETWEEN 87 AND 91 THEN 'Homemaker'      -- 5%
        WHEN (n % 100) BETWEEN 92 AND 95 THEN 'Retired'        -- 4%
        WHEN (n % 100) BETWEEN 96 AND 98 THEN 'Freelancer'     -- 3%
        ELSE 'Unemployed'                                      -- 1%
    END
FROM n;

-----------------------------------------------------------
-- 4) FINAL VALIDATIONS (MANDATORY)
-----------------------------------------------------------

-- 4.1 Total row count (must be 2,000,000)
SELECT COUNT(*) AS CustomerRowCount
FROM core.dim_customer;

-- 4.2 Column count (must be 17)
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_customer');

-- 4.3 Duplicate business keys (must be 0)
SELECT COUNT(*) AS DuplicateCustomerIds
FROM (
    SELECT customer_id
    FROM core.dim_customer
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) d;

-- 4.4 Occupation distribution validation
SELECT
  occupation,
  COUNT(*) AS cnt,
  CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(6,2)) AS pct
FROM core.dim_customer
GROUP BY occupation
ORDER BY cnt DESC;

-- 4.5 Gender distribution validation
SELECT
  gender,
  COUNT(*) AS cnt,
  CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(6,2)) AS pct
FROM core.dim_customer
GROUP BY gender
ORDER BY cnt DESC;

-- 4.6 Preview
SELECT TOP 10 *
FROM core.dim_customer
ORDER BY customer_key;





-----------------------------------------------------------------

/* =========================================================
   DIMENSION: core.dim_policy (FINAL END-to-END)
   Database : insurance_DB
   Schema   : core
   Source   : stg.helper_numbers
   Grain    : 1 row per policy
   Target   : 5,000,000 policies
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
GO   -- only GO before variable declaration

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

IF OBJECT_ID('core.dim_customer','U') IS NULL
BEGIN
    RAISERROR('Table core.dim_customer does not exist. Create dim_customer first.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) Parameters (NO GO after this)
-----------------------------------------------------------
DECLARE @policy_rows   INT = 5000000;   -- 5,000,000 policies
DECLARE @customer_rows BIGINT;

SELECT @customer_rows = COUNT(*) FROM core.dim_customer;

IF @customer_rows IS NULL OR @customer_rows = 0
BEGIN
    RAISERROR('core.dim_customer has 0 rows. Load customers before policies.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 2) DDL: Drop & Create
-----------------------------------------------------------
IF OBJECT_ID('core.dim_policy','U') IS NOT NULL
    DROP TABLE core.dim_policy;

CREATE TABLE core.dim_policy (
    policy_key          BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,
    policy_id           VARCHAR(30)    NOT NULL,     -- business id (unique)
    policy_number       VARCHAR(30)    NOT NULL,     -- display id (unique)

    customer_key        BIGINT        NOT NULL,     -- FK to core.dim_customer (logical)

    product_line        VARCHAR(30)    NOT NULL,     -- Motor/Health/Life/Home/Travel/SME
    policy_type         VARCHAR(30)    NOT NULL,     -- ThirdParty/Comprehensive/Individual/FamilyFloater/etc.
    payment_frequency   VARCHAR(20)    NOT NULL,     -- Monthly/Quarterly/Half-Yearly/Yearly
    policy_status       VARCHAR(20)    NOT NULL,     -- Active/Lapsed/Cancelled/Expired

    issue_date          DATE          NOT NULL,
    start_date          DATE          NOT NULL,
    end_date            DATE          NOT NULL,

    premium_amount      DECIMAL(12,2) NOT NULL,
    sum_insured         DECIMAL(14,2) NOT NULL,

    sales_channel       VARCHAR(20)    NOT NULL,     -- Agent/Online/Branch/Partner
    agent_id            VARCHAR(30)    NULL,         -- optional for later dim_agent mapping

    created_at          DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME(),
    updated_at          DATETIME2(0)   NULL
);

-- Uniqueness
CREATE UNIQUE INDEX UX_dim_policy_policy_id
ON core.dim_policy(policy_id);

CREATE UNIQUE INDEX UX_dim_policy_policy_number
ON core.dim_policy(policy_number);

-- Analytics indexes
CREATE INDEX IX_dim_policy_customer_key
ON core.dim_policy(customer_key);

CREATE INDEX IX_dim_policy_dates
ON core.dim_policy(start_date, end_date);

CREATE INDEX IX_dim_policy_status_product
ON core.dim_policy(policy_status, product_line);

-----------------------------------------------------------
-- 3) DML: Load data (set-based, deterministic, realistic)
-----------------------------------------------------------
;WITH n AS (
    SELECT TOP (@policy_rows) n
    FROM stg.helper_numbers
    ORDER BY n
)
INSERT INTO core.dim_policy (
    policy_id, policy_number, customer_key,
    product_line, policy_type, payment_frequency, policy_status,
    issue_date, start_date, end_date,
    premium_amount, sum_insured,
    sales_channel, agent_id
)
SELECT
    CONCAT('POL', RIGHT('0000000000' + CAST(n AS VARCHAR(10)), 10)) AS policy_id,
    CONCAT('PN',  RIGHT('0000000000' + CAST((n * 11) % 10000000000 AS VARCHAR(10)), 10)) AS policy_number,

    -- Distribute policies across existing customers
    ((n - 1) % @customer_rows) + 1 AS customer_key,

    -- Product line distribution (realistic skew)
    CASE
        WHEN (n % 100) BETWEEN 0  AND 34 THEN 'Motor'    -- 35%
        WHEN (n % 100) BETWEEN 35 AND 59 THEN 'Health'   -- 25%
        WHEN (n % 100) BETWEEN 60 AND 74 THEN 'Life'     -- 15%
        WHEN (n % 100) BETWEEN 75 AND 84 THEN 'Home'     -- 10%
        WHEN (n % 100) BETWEEN 85 AND 92 THEN 'Travel'   -- 8%
        ELSE 'SME'                                      -- 7%
    END AS product_line,

    -- Policy type (mapped by product line + n pattern)
    CASE
        WHEN (n % 100) BETWEEN 0  AND 34 THEN  -- Motor
            CASE WHEN (n % 10) < 6 THEN 'Comprehensive' ELSE 'ThirdParty' END
        WHEN (n % 100) BETWEEN 35 AND 59 THEN  -- Health
            CASE WHEN (n % 10) < 7 THEN 'FamilyFloater' ELSE 'Individual' END
        WHEN (n % 100) BETWEEN 60 AND 74 THEN  -- Life
            CASE WHEN (n % 10) < 7 THEN 'Term' ELSE 'Endowment' END
        WHEN (n % 100) BETWEEN 75 AND 84 THEN  -- Home
            CASE WHEN (n % 10) < 8 THEN 'Structure' ELSE 'Structure+Contents' END
        WHEN (n % 100) BETWEEN 85 AND 92 THEN  -- Travel
            CASE WHEN (n % 10) < 8 THEN 'SingleTrip' ELSE 'MultiTrip' END
        ELSE                                    -- SME
            CASE WHEN (n % 10) < 6 THEN 'Liability' ELSE 'Property' END
    END AS policy_type,

    -- Payment frequency
    CASE
        WHEN (n % 100) BETWEEN 0  AND 69 THEN 'Yearly'       -- 70%
        WHEN (n % 100) BETWEEN 70 AND 84 THEN 'Half-Yearly'  -- 15%
        WHEN (n % 100) BETWEEN 85 AND 94 THEN 'Quarterly'    -- 10%
        ELSE 'Monthly'                                       -- 5%
    END AS payment_frequency,

    -- Status (mostly active)
    CASE
        WHEN (n % 1000) BETWEEN 0  AND 899 THEN 'Active'     -- 90.0%
        WHEN (n % 1000) BETWEEN 900 AND 949 THEN 'Lapsed'    -- 5.0%
        WHEN (n % 1000) BETWEEN 950 AND 979 THEN 'Expired'   -- 3.0%
        ELSE 'Cancelled'                                     -- 2.0%
    END AS policy_status,

    -- Dates: issue/start between 2018-01-01 and 2026-12-31, duration varies
    DATEADD(DAY, (n % 3287), '2018-01-01') AS issue_date,
    DATEADD(DAY, (n % 3287), '2018-01-01') AS start_date,
    DATEADD(DAY,
        (n % 3287) +                                  -- start offset
        CASE                                          -- policy term days
            WHEN (n % 100) BETWEEN 0  AND 79 THEN 365  -- 80% 1-year
            WHEN (n % 100) BETWEEN 80 AND 94 THEN 730  -- 15% 2-year
            ELSE 1095                                  -- 5% 3-year
        END,
        '2018-01-01'
    ) AS end_date,

    -- Premium amount (bounded realistic values, depends on product line)
    CAST(
        CASE
            WHEN (n % 100) BETWEEN 0  AND 34 THEN  2000 + (n % 18000)  -- Motor: 2k–20k
            WHEN (n % 100) BETWEEN 35 AND 59 THEN  3000 + (n % 27000)  -- Health: 3k–30k
            WHEN (n % 100) BETWEEN 60 AND 74 THEN  5000 + (n % 45000)  -- Life: 5k–50k
            WHEN (n % 100) BETWEEN 75 AND 84 THEN  1500 + (n % 13500)  -- Home: 1.5k–15k
            WHEN (n % 100) BETWEEN 85 AND 92 THEN   500 + (n %  4500)  -- Travel: 0.5k–5k
            ELSE                   8000 + (n % 92000)                 -- SME: 8k–100k
        END
        AS DECIMAL(12,2)
    ) AS premium_amount,

    -- Sum insured (bounded, product-based)
    CAST(
        CASE
            WHEN (n % 100) BETWEEN 0  AND 34 THEN 100000 + (n %  900000)    -- Motor: 1L–10L
            WHEN (n % 100) BETWEEN 35 AND 59 THEN 200000 + (n % 1800000)    -- Health: 2L–20L
            WHEN (n % 100) BETWEEN 60 AND 74 THEN 500000 + (n % 9500000)    -- Life: 5L–1Cr
            WHEN (n % 100) BETWEEN 75 AND 84 THEN 300000 + (n % 2700000)    -- Home: 3L–30L
            WHEN (n % 100) BETWEEN 85 AND 92 THEN  50000 + (n %  450000)    -- Travel: 0.5L–5L
            ELSE                   1000000 + (n % 49000000)                -- SME: 10L–5Cr
        END
        AS DECIMAL(14,2)
    ) AS sum_insured,

    -- Sales channel distribution
    CASE
        WHEN (n % 100) BETWEEN 0  AND 44 THEN 'Agent'     -- 45%
        WHEN (n % 100) BETWEEN 45 AND 69 THEN 'Online'    -- 25%
        WHEN (n % 100) BETWEEN 70 AND 84 THEN 'Branch'    -- 15%
        ELSE 'Partner'                                    -- 15%
    END AS sales_channel,

    -- Agent id present mostly when channel is Agent/Partner
    CASE
        WHEN (n % 100) BETWEEN 0 AND 44 THEN CONCAT('AG', RIGHT('000000' + CAST((n % 50000) AS VARCHAR(6)), 6))
        WHEN (n % 100) BETWEEN 85 AND 99 THEN CONCAT('PA', RIGHT('000000' + CAST((n % 20000) AS VARCHAR(6)), 6))
        ELSE NULL
    END AS agent_id
FROM n;

-----------------------------------------------------------
-- 4) Post-insert validations (MANDATORY)
-----------------------------------------------------------

-- 4.1 Row count
SELECT COUNT(*) AS PolicyRowCount
FROM core.dim_policy;

-- 4.2 Column count verification
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_policy');

-- 4.3 Duplicate business key checks (must be 0)
SELECT COUNT(*) AS DuplicatePolicyIds
FROM (
    SELECT policy_id
    FROM core.dim_policy
    GROUP BY policy_id
    HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS DuplicatePolicyNumbers
FROM (
    SELECT policy_number
    FROM core.dim_policy
    GROUP BY policy_number
    HAVING COUNT(*) > 1
) d;

-- 4.4 Customer key integrity check (must be 0)
SELECT COUNT(*) AS InvalidCustomerKeys
FROM core.dim_policy p
LEFT JOIN core.dim_customer c
    ON p.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

-- 4.5 Key business distributions
SELECT product_line, COUNT(*) AS cnt,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(6,2)) AS pct
FROM core.dim_policy
GROUP BY product_line
ORDER BY cnt DESC;

SELECT policy_status, COUNT(*) AS cnt,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(6,2)) AS pct
FROM core.dim_policy
GROUP BY policy_status
ORDER BY cnt DESC;

SELECT sales_channel, COUNT(*) AS cnt,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(6,2)) AS pct
FROM core.dim_policy
GROUP BY sales_channel
ORDER BY cnt DESC;

-- 4.6 Preview
SELECT TOP 10 *
FROM core.dim_policy
ORDER BY policy_key;
