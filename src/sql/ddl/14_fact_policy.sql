/* =========================================================
   FACT: core.fact_policy (END-to-END, SQL Server)
   Grain  : 1 row per policy
   Source : core.dim_policy
========================================================= */

USE insurance_DB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- 0) Safety checks
-----------------------------------------------------------
IF OBJECT_ID('core.dim_policy','U') IS NULL
BEGIN
  RAISERROR('Missing core.dim_policy',16,1);
  RETURN;
END;

IF OBJECT_ID('core.dim_date','U') IS NULL
BEGIN
  RAISERROR('Missing core.dim_date',16,1);
  RETURN;
END;

IF OBJECT_ID('core.dim_policy_status','U') IS NULL
BEGIN
  RAISERROR('Missing core.dim_policy_status',16,1);
  RETURN;
END;

-----------------------------------------------------------
-- 1) DDL (drop + create)
-----------------------------------------------------------
IF OBJECT_ID('core.fact_policy','U') IS NOT NULL
  DROP TABLE core.fact_policy;

CREATE TABLE core.fact_policy (
  policy_fact_key      BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

  policy_key           BIGINT NOT NULL,       -- from dim_policy
  policy_number        VARCHAR(50) NOT NULL,  -- from dim_policy

  customer_key         BIGINT NOT NULL,
  product_key          INT    NOT NULL,

  policy_status_key    INT    NOT NULL,

  start_date_key       INT    NOT NULL,
  end_date_key         INT    NOT NULL,

  sum_insured          DECIMAL(14,2) NOT NULL,

  annual_premium       DECIMAL(14,2) NOT NULL,  -- derived (approx)
  is_active            BIT NOT NULL,
  created_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_fact_policy_policy_key ON core.fact_policy(policy_key);
CREATE INDEX IX_fact_policy_customer_key      ON core.fact_policy(customer_key);
CREATE INDEX IX_fact_policy_product_key       ON core.fact_policy(product_key);
CREATE INDEX IX_fact_policy_status_key        ON core.fact_policy(policy_status_key);
CREATE INDEX IX_fact_policy_start_date_key    ON core.fact_policy(start_date_key);
GO

-----------------------------------------------------------
-- 2) DML (insert from dim_policy, deterministic logic)
-----------------------------------------------------------
;WITH base AS (
  SELECT
    p.policy_key,
    p.policy_number,
    p.customer_key,
    p.product_key,
    p.start_date,
    p.end_date,
    p.sum_insured,
    ROW_NUMBER() OVER (ORDER BY p.policy_key) AS rn
  FROM core.dim_policy p
),
status_map AS (
  SELECT
    b.*,
    -- realistic status distribution using rn:
    -- 62% Active, 10% Pending, 10% Renewed, 8% Expired, 6% Lapsed, 4% Cancelled
    CASE
      WHEN (b.rn % 100) < 62 THEN 'POL_ACTIVE'
      WHEN (b.rn % 100) < 72 THEN 'POL_PENDING'
      WHEN (b.rn % 100) < 82 THEN 'POL_RENEWED'
      WHEN (b.rn % 100) < 90 THEN 'POL_EXPIRED'
      WHEN (b.rn % 100) < 96 THEN 'POL_LAPSED'
      ELSE 'POL_CANCELLED'
    END AS policy_status_code
  FROM base b
),
keys AS (
  SELECT
    s.policy_key,
    s.policy_number,
    s.customer_key,
    s.product_key,
    ps.policy_status_key,
    d1.date_key AS start_date_key,
    d2.date_key AS end_date_key,
    CAST(s.sum_insured AS DECIMAL(14,2)) AS sum_insured,
    s.rn
  FROM status_map s
  JOIN core.dim_policy_status ps
    ON ps.policy_status_code = s.policy_status_code
  JOIN core.dim_date d1
    ON d1.full_date = s.start_date
  JOIN core.dim_date d2
    ON d2.full_date = s.end_date
),
final_rows AS (
  SELECT
    k.*,
    -- annual premium: approx = sum_insured * rate (product dependent simulated via rn)
    CAST(
      (k.sum_insured * (
        CASE
          WHEN (k.rn % 10) IN (0,1) THEN 0.012  -- 1.2%
          WHEN (k.rn % 10) IN (2,3,4) THEN 0.018 -- 1.8%
          WHEN (k.rn % 10) IN (5,6,7) THEN 0.025 -- 2.5%
          ELSE 0.032                              -- 3.2%
        END
      ))
      AS DECIMAL(14,2)
    ) AS annual_premium,

    CASE WHEN k.policy_status_key IN (
        SELECT policy_status_key FROM core.dim_policy_status WHERE policy_status_code IN ('POL_ACTIVE','POL_RENEWED')
    ) THEN 1 ELSE 0 END AS is_active
  FROM keys k
)
INSERT INTO core.fact_policy (
  policy_key, policy_number,
  customer_key, product_key,
  policy_status_key,
  start_date_key, end_date_key,
  sum_insured, annual_premium,
  is_active
)
SELECT
  policy_key, policy_number,
  customer_key, product_key,
  policy_status_key,
  start_date_key, end_date_key,
  sum_insured, annual_premium,
  is_active
FROM final_rows;

-----------------------------------------------------------
-- 3) Validations (must run)
-----------------------------------------------------------

-- Row count (should equal dim_policy count)
SELECT
  (SELECT COUNT(*) FROM core.dim_policy)    AS DimPolicyCount,
  (SELECT COUNT(*) FROM core.fact_policy)   AS FactPolicyCount;

-- Column count
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.fact_policy');

-- Duplicate policies (must be 0)
SELECT COUNT(*) AS DuplicatePolicyKeys
FROM (
  SELECT policy_key
  FROM core.fact_policy
  GROUP BY policy_key
  HAVING COUNT(*) > 1
) d;

-- Key integrity (must be 0)
SELECT COUNT(*) AS InvalidStartDateKeys
FROM core.fact_policy f
LEFT JOIN core.dim_date d ON f.start_date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT COUNT(*) AS InvalidEndDateKeys
FROM core.fact_policy f
LEFT JOIN core.dim_date d ON f.end_date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT COUNT(*) AS InvalidPolicyStatusKeys
FROM core.fact_policy f
LEFT JOIN core.dim_policy_status s ON f.policy_status_key = s.policy_status_key
WHERE s.policy_status_key IS NULL;

-- Status distribution sanity
SELECT s.policy_status_name, COUNT(*) AS cnt
FROM core.fact_policy f
JOIN core.dim_policy_status s ON f.policy_status_key = s.policy_status_key
GROUP BY s.policy_status_name
ORDER BY cnt DESC;

-- Preview
SELECT TOP 10 *
FROM core.fact_policy
ORDER BY policy_fact_key DESC;
GO
