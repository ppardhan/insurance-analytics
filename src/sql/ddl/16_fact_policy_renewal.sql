/* =========================================================
   FACT: core.fact_policy_renewal (END-to-END)
   Grain  : 1 row per policy renewal
   Source : core.fact_policy + core.dim_policy
========================================================= */

USE insurance_DB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- 0) Safety checks
-----------------------------------------------------------
IF OBJECT_ID('core.fact_policy','U') IS NULL
BEGIN
  RAISERROR('Missing core.fact_policy',16,1);
  RETURN;
END;

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

-----------------------------------------------------------
-- 1) DDL
-----------------------------------------------------------
IF OBJECT_ID('core.fact_policy_renewal','U') IS NOT NULL
  DROP TABLE core.fact_policy_renewal;
GO

CREATE TABLE core.fact_policy_renewal (
  policy_renewal_key      BIGINT IDENTITY(1,1) PRIMARY KEY,

  policy_key              BIGINT NOT NULL,
  customer_key            BIGINT NOT NULL,
  product_key             INT    NOT NULL,

  previous_end_date_key   INT    NOT NULL,
  renewal_date_key        INT    NOT NULL,

  renewal_sequence_no     INT    NOT NULL,   -- 1st renewal, 2nd, etc.
  renewal_status          VARCHAR(20) NOT NULL, -- Renewed / NotRenewed
  renewal_premium         DECIMAL(14,2) NOT NULL,
  premium_change_pct      DECIMAL(6,2)  NOT NULL,

  created_at              DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE INDEX IX_fpr_policy_key ON core.fact_policy_renewal(policy_key);
GO

-----------------------------------------------------------
-- 2) DML (deterministic + realistic)
-----------------------------------------------------------
;WITH base AS (
    SELECT
        f.policy_key,
        f.customer_key,
        f.product_key,
        f.end_date_key,
        f.annual_premium,
        ROW_NUMBER() OVER (ORDER BY f.policy_key) AS rn
    FROM core.fact_policy f
),
eligible AS (
    -- ~40% policies considered for renewal
    SELECT *
    FROM base
    WHERE rn % 100 < 40
),
dates AS (
    SELECT
        e.*,
        d.full_date AS prev_end_date,
        DATEADD(DAY, 1, d.full_date) AS renewal_dt
    FROM eligible e
    JOIN core.dim_date d
      ON d.date_key = e.end_date_key
),
keys AS (
    SELECT
        d.policy_key,
        d.customer_key,
        d.product_key,
        d.end_date_key AS previous_end_date_key,
        dd.date_key    AS renewal_date_key,
        d.annual_premium,
        d.rn
    FROM dates d
    JOIN core.dim_date dd
      ON dd.full_date = d.renewal_dt
)
INSERT INTO core.fact_policy_renewal (
    policy_key, customer_key, product_key,
    previous_end_date_key, renewal_date_key,
    renewal_sequence_no, renewal_status,
    renewal_premium, premium_change_pct
)
SELECT
    k.policy_key,
    k.customer_key,
    k.product_key,
    k.previous_end_date_key,
    k.renewal_date_key,

    (k.rn % 3) + 1 AS renewal_sequence_no, -- up to 3 renewals

    CASE
        WHEN k.rn % 100 < 85 THEN 'Renewed'
        ELSE 'NotRenewed'
    END AS renewal_status,

    CAST(
        k.annual_premium *
        (1 + ((k.rn % 11) - 5) / 100.0)   -- -5% to +5%
    AS DECIMAL(14,2)) AS renewal_premium,

    CAST(((k.rn % 11) - 5) AS DECIMAL(6,2)) AS premium_change_pct
FROM keys k;
GO

-----------------------------------------------------------
-- 3) Validations
-----------------------------------------------------------
SELECT COUNT(*) AS PolicyRenewalRowCount
FROM core.fact_policy_renewal;

SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.fact_policy_renewal');

SELECT COUNT(*) AS InvalidPolicyKeys
FROM core.fact_policy_renewal r
LEFT JOIN core.fact_policy p ON r.policy_key = p.policy_key
WHERE p.policy_key IS NULL;

SELECT COUNT(*) AS InvalidRenewalDateKeys
FROM core.fact_policy_renewal r
LEFT JOIN core.dim_date d ON r.renewal_date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT renewal_status, COUNT(*) AS cnt
FROM core.fact_policy_renewal
GROUP BY renewal_status;

SELECT TOP 10 *
FROM core.fact_policy_renewal
ORDER BY policy_renewal_key DESC;
GO
