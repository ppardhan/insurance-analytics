USE insurance_DB;
GO

-----------------------------------------------------------
-- 0) Reduce deadlock noise (optional)
-----------------------------------------------------------
SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- 1) Drop & recreate fact table
-----------------------------------------------------------
IF OBJECT_ID('core.fact_premium','U') IS NOT NULL
    DROP TABLE core.fact_premium;

CREATE TABLE core.fact_premium (
    premium_key        BIGINT        IDENTITY(1,1) NOT NULL PRIMARY KEY,

    policy_key         BIGINT        NOT NULL,
    customer_key       BIGINT        NOT NULL,
    product_key        INT           NOT NULL,

    premium_date_key   INT           NOT NULL,
    due_date_key       INT           NOT NULL,

    payment_frequency  VARCHAR(20)   NOT NULL,
    payment_status     VARCHAR(20)   NOT NULL,
    payment_method     VARCHAR(20)   NOT NULL,

    gross_premium      DECIMAL(12,2) NOT NULL,
    discount_amount    DECIMAL(12,2) NOT NULL,
    tax_amount         DECIMAL(12,2) NOT NULL,
    net_premium        DECIMAL(12,2) NOT NULL,

    created_at         DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME()
);

-- Create indexes AFTER load to reduce logging/locking during insert
-- (we’ll add them later)

-----------------------------------------------------------
-- 2) Parameters
-----------------------------------------------------------
DECLARE @fact_rows BIGINT = 30000000;     -- total target
DECLARE @batch     INT    = 500000;       -- batch size (lower if still errors)
DECLARE @start     BIGINT = 1;
DECLARE @end       BIGINT;

DECLARE @policy_cnt BIGINT;
SELECT @policy_cnt = COUNT(*) FROM core.dim_policy;

IF @policy_cnt IS NULL OR @policy_cnt = 0
BEGIN
    RAISERROR('core.dim_policy has 0 rows. Load dim_policy first.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 3) Batched insert loop
-----------------------------------------------------------
WHILE @start <= @fact_rows
BEGIN
    SET @end = CASE WHEN @start + @batch - 1 > @fact_rows THEN @fact_rows ELSE @start + @batch - 1 END;

    BEGIN TRAN;

    ;WITH seq AS (
        SELECT n.n AS seq
        FROM stg.helper_numbers n
        WHERE n.n BETWEEN @start AND @end
    ),
    policy_pick AS (
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
            p.payment_frequency,
            p.premium_amount,
            p.start_date,
            p.end_date,
            ROW_NUMBER() OVER (ORDER BY p.policy_key) AS rn
        FROM core.dim_policy p
    ),
    joined AS (
        SELECT
            pp.seq,
            p.policy_key,
            p.customer_key,
            p.product_key,
            p.payment_frequency,
            p.premium_amount,
            p.start_date,
            p.end_date,
            CASE
                WHEN DATEDIFF(DAY, p.start_date, p.end_date) < 1 THEN 1
                ELSE DATEDIFF(DAY, p.start_date, p.end_date)
            END AS dur_days
        FROM policy_pick pp
        JOIN pol p
          ON p.rn = pp.pol_rn
    ),
    dates AS (
        SELECT
            j.*,
            DATEADD(DAY, (j.seq % j.dur_days), j.start_date) AS premium_dt,
            DATEADD(DAY, (j.seq % j.dur_days), j.start_date) AS due_dt
        FROM joined j
    ),
    final_rows AS (
        SELECT
            d.policy_key,
            d.customer_key,
            d.product_key,
            dd1.date_key AS premium_date_key,
            dd2.date_key AS due_date_key,
            d.payment_frequency,
            d.seq,
            d.premium_amount
        FROM dates d
        JOIN core.dim_date dd1 ON dd1.full_date = d.premium_dt
        JOIN core.dim_date dd2 ON dd2.full_date = d.due_dt
    )
    INSERT INTO core.fact_premium (
        policy_key, customer_key, product_key,
        premium_date_key, due_date_key,
        payment_frequency, payment_status, payment_method,
        gross_premium, discount_amount, tax_amount, net_premium
    )
    SELECT
        f.policy_key,
        f.customer_key,
        f.product_key,
        f.premium_date_key,
        f.due_date_key,
        f.payment_frequency,

        CASE
            WHEN (f.seq % 1000) BETWEEN 0 AND 899 THEN 'Paid'
            WHEN (f.seq % 1000) BETWEEN 900 AND 949 THEN 'Due'
            WHEN (f.seq % 1000) BETWEEN 950 AND 989 THEN 'Overdue'
            ELSE 'Failed'
        END,

        CASE
            WHEN (f.seq % 100) BETWEEN 0 AND 49 THEN 'UPI'
            WHEN (f.seq % 100) BETWEEN 50 AND 69 THEN 'Card'
            WHEN (f.seq % 100) BETWEEN 70 AND 84 THEN 'NetBanking'
            WHEN (f.seq % 100) BETWEEN 85 AND 94 THEN 'Wallet'
            ELSE 'Cash'
        END,

        CAST(f.premium_amount * (1 + ((f.seq % 7) - 3) * 0.01) AS DECIMAL(12,2)),

        CAST(
            CASE
                WHEN (f.seq % 10) = 0 THEN f.premium_amount * 0.10
                WHEN (f.seq % 10) = 1 THEN f.premium_amount * 0.05
                ELSE 0
            END AS DECIMAL(12,2)
        ),

        CAST(
            (
                (f.premium_amount * (1 + ((f.seq % 7) - 3) * 0.01))
                - (CASE WHEN (f.seq % 10) = 0 THEN f.premium_amount * 0.10
                        WHEN (f.seq % 10) = 1 THEN f.premium_amount * 0.05
                        ELSE 0 END)
            ) * 0.18
            AS DECIMAL(12,2)
        ),

        CAST(
            (f.premium_amount * (1 + ((f.seq % 7) - 3) * 0.01))
            - (CASE WHEN (f.seq % 10) = 0 THEN f.premium_amount * 0.10
                    WHEN (f.seq % 10) = 1 THEN f.premium_amount * 0.05
                    ELSE 0 END)
            + (
                (
                    (f.premium_amount * (1 + ((f.seq % 7) - 3) * 0.01))
                    - (CASE WHEN (f.seq % 10) = 0 THEN f.premium_amount * 0.10
                            WHEN (f.seq % 10) = 1 THEN f.premium_amount * 0.05
                            ELSE 0 END)
                ) * 0.18
              )
            AS DECIMAL(12,2)
        )
    FROM final_rows f;

    COMMIT;

    PRINT CONCAT('Loaded rows: ', @start, ' to ', @end);

    SET @start = @end + 1;
END;

-----------------------------------------------------------
-- 4) Add indexes after load (faster/safer)
-----------------------------------------------------------
CREATE INDEX IX_fact_premium_premium_date_key ON core.fact_premium(premium_date_key);
CREATE INDEX IX_fact_premium_policy_key       ON core.fact_premium(policy_key);
CREATE INDEX IX_fact_premium_customer_key     ON core.fact_premium(customer_key);
CREATE INDEX IX_fact_premium_product_key      ON core.fact_premium(product_key);

-----------------------------------------------------------
-- 5) Validations
-----------------------------------------------------------
SELECT COUNT(*) AS PremiumRowCount FROM core.fact_premium;

SELECT COUNT(*) AS InvalidPremiumDateKeys
FROM core.fact_premium f
LEFT JOIN core.dim_date d ON f.premium_date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT COUNT(*) AS InvalidDueDateKeys
FROM core.fact_premium f
LEFT JOIN core.dim_date d ON f.due_date_key = d.date_key
WHERE d.date_key IS NULL;

select * from core.fact_premium

USE insurance_DB;

SELECT
  (SELECT MIN(full_date) FROM core.dim_date) AS dim_date_min,
  (SELECT MAX(full_date) FROM core.dim_date) AS dim_date_max,
  (SELECT MIN(start_date) FROM core.dim_policy) AS policy_start_min,
  (SELECT MAX(end_date)   FROM core.dim_policy) AS policy_end_max,
  (SELECT COUNT(*) FROM core.dim_policy WHERE end_date > (SELECT MAX(full_date) FROM core.dim_date)) AS policies_beyond_dim_date;
