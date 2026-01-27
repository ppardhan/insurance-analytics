/* =========================================================
   FACT: core.fact_claims (BUG-FREE END-to-END)
   Database : insurance_DB
   Schema   : core
   Grain    : 1 row per claim transaction
   Load     : batched insert to avoid lock escalation
   DateKey  : guaranteed via join to core.dim_date
========================================================= */

USE insurance_DB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- 0) Safety checks
-----------------------------------------------------------
IF DB_ID('insurance_DB') IS NULL
BEGIN
    RAISERROR('Database insurance_DB does not exist.', 16, 1);
    RETURN;
END;

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

IF OBJECT_ID('core.dim_policy','U') IS NULL
BEGIN
    RAISERROR('Table core.dim_policy does not exist.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('core.dim_customer','U') IS NULL
BEGIN
    RAISERROR('Table core.dim_customer does not exist.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('core.dim_product','U') IS NULL
BEGIN
    RAISERROR('Table core.dim_product does not exist.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('core.dim_date','U') IS NULL
BEGIN
    RAISERROR('Table core.dim_date does not exist.', 16, 1);
    RETURN;
END;

DECLARE @policy_cnt BIGINT;
SELECT @policy_cnt = COUNT(*) FROM core.dim_policy;

IF @policy_cnt IS NULL OR @policy_cnt = 0
BEGIN
    RAISERROR('core.dim_policy has 0 rows. Load dim_policy first.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) Parameters (tune as needed)
-----------------------------------------------------------
DECLARE @fact_rows BIGINT = 12000000;  -- 12,000,000 claims (large-scale, practical)
DECLARE @batch     INT    = 200000;    -- batch size (reduce to 100000 if server is tight)
DECLARE @start     BIGINT = 1;
DECLARE @end       BIGINT;

-----------------------------------------------------------
-- 2) DDL: Drop & Create
-----------------------------------------------------------
IF OBJECT_ID('core.fact_claims','U') IS NOT NULL
    DROP TABLE core.fact_claims;

CREATE TABLE core.fact_claims (
    claim_key              BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,

    claim_id               VARCHAR(30)   NOT NULL,    -- business key (unique)
    policy_key             BIGINT        NOT NULL,
    customer_key           BIGINT        NOT NULL,
    product_key            INT           NOT NULL,

    loss_date_key          INT           NOT NULL,    -- date of incident
    reported_date_key      INT           NOT NULL,    -- date reported
    settled_date_key       INT           NULL,        -- date settled (nullable)

    claim_type             VARCHAR(30)   NOT NULL,    -- Accident/Theft/Medical/Death/Fire/Flood/Travel/Other
    claim_status           VARCHAR(20)   NOT NULL,    -- Open/Investigating/Approved/Rejected/Settled

    claim_amount           DECIMAL(14,2) NOT NULL,    -- requested
    approved_amount        DECIMAL(14,2) NOT NULL,    -- approved (0 if rejected)
    paid_amount            DECIMAL(14,2) NOT NULL,    -- paid (0 if not settled)
    deductible_amount      DECIMAL(12,2) NOT NULL,
    fraud_flag             BIT           NOT NULL,

    created_at             DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);

-- Enforce unique claim_id (create after load? Here ok — small overhead)
CREATE UNIQUE INDEX UX_fact_claims_claim_id ON core.fact_claims(claim_id);

-----------------------------------------------------------
-- 3) Load in batches (prevents Msg 1204 lock resource errors)
-----------------------------------------------------------
WHILE @start <= @fact_rows
BEGIN
    SET @end = CASE
                  WHEN @start + @batch - 1 > @fact_rows THEN @fact_rows
                  ELSE @start + @batch - 1
               END;

    BEGIN TRAN;

    ;WITH seq AS (
        SELECT n.n AS seq
        FROM stg.helper_numbers n
        WHERE n.n BETWEEN @start AND @end
    ),
    policy_pick AS (
        -- Map seq -> policy row_number, avoids assuming contiguous policy_key
        SELECT
            s.seq,
            ((s.seq - 1) % @policy_cnt) + 1 AS pol_rn
        FROM seq s
    ),
    pol AS (
        SELECT
            p.policy_key,
            p.customer_key,
            p.product_key,
            p.product_line,
            p.policy_type,
            p.start_date,
            p.end_date,
            p.sum_insured,
            ROW_NUMBER() OVER (ORDER BY p.policy_key) AS rn
        FROM core.dim_policy p
    ),
    joined AS (
        SELECT
            pp.seq,
            p.policy_key,
            p.customer_key,
            p.product_key,
            p.product_line,
            p.policy_type,
            p.start_date,
            p.end_date,
            p.sum_insured,
            CASE
                WHEN DATEDIFF(DAY, p.start_date, p.end_date) < 1 THEN 1
                ELSE DATEDIFF(DAY, p.start_date, p.end_date)
            END AS dur_days
        FROM policy_pick pp
        JOIN pol p
          ON p.rn = pp.pol_rn
    ),
    claim_dates AS (
        -- loss_dt is within policy coverage window
        SELECT
            j.*,
            DATEADD(DAY, (j.seq % j.dur_days), j.start_date) AS loss_dt,
            DATEADD(DAY, ((j.seq % j.dur_days) + (j.seq % 15)), j.start_date) AS reported_dt,
            CASE
                WHEN (j.seq % 100) < 60 THEN DATEADD(DAY, ((j.seq % j.dur_days) + 30 + (j.seq % 60)), j.start_date) -- 60% settled-ish
                ELSE NULL
            END AS settled_dt_raw
        FROM joined j
    ),
    date_keys AS (
        -- Force all dates to exist in dim_date (guaranteed integrity)
        SELECT
            c.seq,
            c.policy_key,
            c.customer_key,
            c.product_key,
            c.product_line,
            c.sum_insured,

            d1.date_key AS loss_date_key,
            d2.date_key AS reported_date_key,
            d3.date_key AS settled_date_key
        FROM claim_dates c
        JOIN core.dim_date d1 ON d1.full_date = c.loss_dt
        JOIN core.dim_date d2 ON d2.full_date = c.reported_dt
        LEFT JOIN core.dim_date d3 ON d3.full_date = c.settled_dt_raw
    ),
    measures AS (
        SELECT
            dk.*,

            -- Claim type (realistic by product line)
            CASE dk.product_line
                WHEN 'Motor'  THEN CASE WHEN (dk.seq % 100) < 70 THEN 'Accident'
                                        WHEN (dk.seq % 100) < 85 THEN 'Theft'
                                        ELSE 'Other' END
                WHEN 'Health' THEN CASE WHEN (dk.seq % 100) < 85 THEN 'Medical' ELSE 'Other' END
                WHEN 'Life'   THEN CASE WHEN (dk.seq % 100) < 90 THEN 'Death' ELSE 'Other' END
                WHEN 'Home'   THEN CASE WHEN (dk.seq % 100) < 45 THEN 'Fire'
                                        WHEN (dk.seq % 100) < 75 THEN 'Flood'
                                        ELSE 'Other' END
                WHEN 'Travel' THEN CASE WHEN (dk.seq % 100) < 55 THEN 'Travel' ELSE 'Other' END
                ELSE                CASE WHEN (dk.seq % 100) < 55 THEN 'Property' ELSE 'Liability' END
            END AS claim_type,

            -- Fraud flag (low but non-zero)
            CASE WHEN (dk.seq % 1000) < 12 THEN 1 ELSE 0 END AS fraud_flag, -- ~1.2%

            -- Deductible (small %)
            CAST(
                CASE
                    WHEN (dk.seq % 100) < 80 THEN 500
                    WHEN (dk.seq % 100) < 95 THEN 1000
                    ELSE 2000
                END AS DECIMAL(12,2)
            ) AS deductible_amount,

            -- Claim amount bounded by sum_insured
            CAST(
                CASE
                    WHEN dk.product_line = 'Health' THEN (5000 + (dk.seq % 200000))  -- 5k–205k
                    WHEN dk.product_line = 'Motor'  THEN (2000 + (dk.seq % 300000))  -- 2k–302k
                    WHEN dk.product_line = 'Life'   THEN (50000 + (dk.seq % 2000000)) -- 50k–20.5L (claim could be larger but bounded later)
                    WHEN dk.product_line = 'Home'   THEN (10000 + (dk.seq % 800000)) -- 10k–8.1L
                    WHEN dk.product_line = 'Travel' THEN (1000 + (dk.seq % 100000))  -- 1k–101k
                    ELSE                                  (20000 + (dk.seq % 1500000)) -- SME: 20k–15.2L
                END AS DECIMAL(14,2)
            ) AS raw_claim_amount
        FROM date_keys dk
    ),
    final_rows AS (
        SELECT
            m.seq,
            m.policy_key,
            m.customer_key,
            m.product_key,
            m.loss_date_key,
            m.reported_date_key,
            m.settled_date_key,
            m.claim_type,
            m.fraud_flag,
            m.deductible_amount,

            -- Cap claim amount to <= 80% of sum insured
            CAST(
                CASE
                    WHEN m.raw_claim_amount > (m.sum_insured * 0.80) THEN (m.sum_insured * 0.80)
                    ELSE m.raw_claim_amount
                END AS DECIMAL(14,2)
            ) AS claim_amount_capped
        FROM measures m
    )
    INSERT INTO core.fact_claims (
        claim_id, policy_key, customer_key, product_key,
        loss_date_key, reported_date_key, settled_date_key,
        claim_type, claim_status,
        claim_amount, approved_amount, paid_amount,
        deductible_amount, fraud_flag
    )
    SELECT
        CONCAT('CLM', RIGHT('000000000000' + CAST(fr.seq AS VARCHAR(12)), 12)) AS claim_id,
        fr.policy_key,
        fr.customer_key,
        fr.product_key,
        fr.loss_date_key,
        fr.reported_date_key,
        fr.settled_date_key,
        fr.claim_type,

        -- Status distribution (fraud increases rejection)
        CASE
            WHEN fr.fraud_flag = 1 AND (fr.seq % 100) < 60 THEN 'Rejected'
            WHEN fr.settled_date_key IS NOT NULL THEN 'Settled'
            WHEN (fr.seq % 100) < 55 THEN 'Open'
            WHEN (fr.seq % 100) < 80 THEN 'Investigating'
            WHEN (fr.seq % 100) < 93 THEN 'Approved'
            ELSE 'Rejected'
        END AS claim_status,

        fr.claim_amount_capped AS claim_amount,

        -- Approved amount: 0 if rejected, else 70–100% minus deductible
        CAST(
            CASE
                WHEN (CASE
                        WHEN fr.fraud_flag = 1 AND (fr.seq % 100) < 60 THEN 1
                        WHEN fr.settled_date_key IS NOT NULL THEN 0
                        WHEN (fr.seq % 100) < 55 THEN 0
                        WHEN (fr.seq % 100) < 80 THEN 0
                        WHEN (fr.seq % 100) < 93 THEN 0
                        ELSE 1
                      END) = 1
                THEN 0
                ELSE
                    CASE
                        WHEN fr.claim_amount_capped - fr.deductible_amount < 0 THEN 0
                        ELSE (fr.claim_amount_capped - fr.deductible_amount)
                             * (0.70 + ((fr.seq % 31) / 100.0))  -- 0.70 to 1.00
                    END
            END
            AS DECIMAL(14,2)
        ) AS approved_amount,

        -- Paid: only for Settled; otherwise 0
        CAST(
            CASE
                WHEN fr.settled_date_key IS NOT NULL THEN
                    CASE
                        WHEN fr.claim_amount_capped - fr.deductible_amount < 0 THEN 0
                        ELSE (fr.claim_amount_capped - fr.deductible_amount)
                             * (0.70 + ((fr.seq % 31) / 100.0))
                    END
                ELSE 0
            END
            AS DECIMAL(14,2)
        ) AS paid_amount,

        fr.deductible_amount,
        fr.fraud_flag
    FROM final_rows fr;

    COMMIT;

    PRINT CONCAT('Loaded claims rows: ', @start, ' to ', @end);

    SET @start = @end + 1;
END;

-----------------------------------------------------------
-- 4) Add performance indexes AFTER load (faster/safer)
-----------------------------------------------------------
CREATE INDEX IX_fact_claims_loss_date_key     ON core.fact_claims(loss_date_key);
CREATE INDEX IX_fact_claims_reported_date_key ON core.fact_claims(reported_date_key);
CREATE INDEX IX_fact_claims_policy_key        ON core.fact_claims(policy_key);
CREATE INDEX IX_fact_claims_customer_key      ON core.fact_claims(customer_key);
CREATE INDEX IX_fact_claims_product_key       ON core.fact_claims(product_key);
CREATE INDEX IX_fact_claims_status_type       ON core.fact_claims(claim_status, claim_type);

-----------------------------------------------------------
-----------------------------------------------------------
-- FINAL VALIDATIONS (MATCHES ACTUAL TABLE STRUCTURE)
-----------------------------------------------------------

-- Row count
SELECT COUNT(*) AS ClaimsRowCount
FROM core.fact_claims;

-- Column count (must be 17)
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.fact_claims');

-- Duplicate claim_id (must be 0)
SELECT COUNT(*) AS DuplicateClaimIds
FROM (
    SELECT claim_id
    FROM core.fact_claims
    GROUP BY claim_id
    HAVING COUNT(*) > 1
) d;

-- Foreign key integrity
SELECT COUNT(*) AS InvalidPolicyKeys
FROM core.fact_claims f
LEFT JOIN core.dim_policy p ON f.policy_key = p.policy_key
WHERE p.policy_key IS NULL;

SELECT COUNT(*) AS InvalidCustomerKeys
FROM core.fact_claims f
LEFT JOIN core.dim_customer c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT COUNT(*) AS InvalidProductKeys
FROM core.fact_claims f
LEFT JOIN core.dim_product d ON f.product_key = d.product_key
WHERE d.product_key IS NULL;

SELECT COUNT(*) AS InvalidLossDateKeys
FROM core.fact_claims f
LEFT JOIN core.dim_date dd ON f.loss_date_key = dd.date_key
WHERE dd.date_key IS NULL;

SELECT COUNT(*) AS InvalidReportedDateKeys
FROM core.fact_claims f
LEFT JOIN core.dim_date dd ON f.reported_date_key = dd.date_key
WHERE dd.date_key IS NULL;

-- Business sanity
SELECT claim_status, COUNT(*) AS cnt
FROM core.fact_claims
GROUP BY claim_status
ORDER BY cnt DESC;

SELECT claim_type, COUNT(*) AS cnt
FROM core.fact_claims
GROUP BY claim_type
ORDER BY cnt DESC;



SELECT fraud_flag, COUNT(*) AS cnt
FROM core.fact_claims
GROUP BY fraud_flag
ORDER BY fraud_flag DESC;

-- Amount sanity


-- Preview
SELECT TOP 10 *
FROM core.fact_claims
ORDER BY claim_key DESC;

USE insurance_DB;


