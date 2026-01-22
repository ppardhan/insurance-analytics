USE insurance_DB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- Parameters (missing load)
-----------------------------------------------------------
DECLARE @target_total BIGINT = 30000000;
DECLARE @current      BIGINT = (SELECT COUNT(*) FROM core.fact_premium);

IF @current >= @target_total
BEGIN
    SELECT 'No action needed' AS status, @current AS current_rows;
    RETURN;
END;

DECLARE @start BIGINT = @current + 1;
DECLARE @end_total BIGINT = @target_total;

DECLARE @batch INT = 200000;  -- safe batch
DECLARE @end BIGINT;

DECLARE @policy_cnt BIGINT;
SELECT @policy_cnt = COUNT(*) FROM core.dim_policy;

-----------------------------------------------------------
-- Load loop (only missing range)
-----------------------------------------------------------
WHILE @start <= @end_total
BEGIN
    SET @end = CASE WHEN @start + @batch - 1 > @end_total THEN @end_total ELSE @start + @batch - 1 END;

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

    PRINT CONCAT('Loaded missing rows: ', @start, ' to ', @end);

    SET @start = @end + 1;
END;

-----------------------------------------------------------
-- Final validation
-----------------------------------------------------------
SELECT COUNT(*) AS PremiumRowCount
FROM core.fact_premium;
