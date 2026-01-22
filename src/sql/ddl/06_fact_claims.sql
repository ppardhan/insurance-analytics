    /* =========================================================
    FINAL FAST FACT LOAD – core.fact_claims
    Optimized for VS Code + SQL Server
    ========================================================= */

    -----------------------------------------------------------
    -- 0) Safety checks
    -----------------------------------------------------------
    IF DB_ID(N'insurance_DB') IS NULL
        THROW 50000, 'Database insurance_DB does not exist.', 1;

    USE insurance_DB;
    GO

    IF OBJECT_ID('stg.helper_numbers','U') IS NULL
        THROW 50001, 'stg.helper_numbers missing.', 1;

    IF OBJECT_ID('core.dim_policy','U') IS NULL
        THROW 50002, 'core.dim_policy missing.', 1;

    IF OBJECT_ID('core.dim_date','U') IS NULL
        THROW 50003, 'core.dim_date missing.', 1;

    -----------------------------------------------------------
    -- 1) Parameters (FAST + SAFE)
    -----------------------------------------------------------
    DECLARE @claim_rows BIGINT = 29000000;  -- 👉 change to 12000000 later
    DECLARE @batch_size INT = 500000;
    DECLARE @start BIGINT = 1;
    DECLARE @end BIGINT;

    DECLARE @policy_cnt BIGINT;

    SELECT @policy_cnt = COUNT(*) FROM core.dim_policy;

    IF @policy_cnt = 0
        THROW 50004, 'dim_policy is empty.', 1;

    -----------------------------------------------------------
    -- 2) Drop & Create FACT (NO INDEXES YET)
    -----------------------------------------------------------
    IF OBJECT_ID('core.fact_claims','U') IS NOT NULL
        DROP TABLE core.fact_claims;

    CREATE TABLE core.fact_claims (
        claim_key BIGINT IDENTITY PRIMARY KEY,
        claim_id VARCHAR(30) NOT NULL,

        policy_key BIGINT NOT NULL,
        customer_key BIGINT NOT NULL,
        product_key INT NOT NULL,

        loss_date_key INT NOT NULL,
        reported_date_key INT NOT NULL,
        closed_date_key INT NULL,

        claim_status VARCHAR(20) NOT NULL,
        claim_type VARCHAR(40) NOT NULL,
        claim_severity VARCHAR(20) NOT NULL,

        claim_amount DECIMAL(14,2) NOT NULL,
        approved_amount DECIMAL(14,2) NOT NULL,
        payout_amount DECIMAL(14,2) NOT NULL,
        deductible_amount DECIMAL(12,2) NOT NULL,

        fraud_flag BIT NOT NULL,
        created_at DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
    );

    -----------------------------------------------------------
    -- 3) FAST BATCH LOAD (KEY SECTION)
    -----------------------------------------------------------
    WHILE @start <= @claim_rows
    BEGIN
        SET @end = @start + @batch_size - 1;

        ;WITH seq AS (
            SELECT n.n AS seq
            FROM stg.helper_numbers n
            WHERE n.n BETWEEN @start AND @end
        ),
        pol AS (
            SELECT *,
                ROW_NUMBER() OVER (ORDER BY policy_key) AS rn
            FROM core.dim_policy
        ),
        j AS (
            SELECT
                s.seq,
                p.policy_key,
                p.customer_key,
                p.product_key,
                p.product_line,
                p.start_date,
                p.end_date,
                p.sum_insured,
                CASE
                    WHEN DATEDIFF(DAY, p.start_date, p.end_date) < 1 THEN 1
                    ELSE DATEDIFF(DAY, p.start_date, p.end_date)
                END AS dur_days
            FROM seq s
            JOIN pol p
            ON p.rn = ((s.seq - 1) % @policy_cnt) + 1
        ),
        d AS (
            SELECT *,
                DATEADD(DAY, seq % dur_days, start_date) AS loss_dt,
                DATEADD(DAY, seq % 15,
                    DATEADD(DAY, seq % dur_days, start_date)) AS reported_dt,
                CASE
                    WHEN seq % 100 < 55 THEN NULL
                    ELSE DATEADD(DAY, 30, start_date)
                END AS closed_dt
            FROM j
        ),
        k AS (
            SELECT
                d.seq,
                d.policy_key,
                d.customer_key,
                d.product_key,
                d.product_line,
                d.sum_insured,
                dl.date_key AS loss_date_key,
                dr.date_key AS reported_date_key,
                dc.date_key AS closed_date_key
            FROM d
            JOIN core.dim_date dl ON dl.full_date = d.loss_dt
            JOIN core.dim_date dr ON dr.full_date = d.reported_dt
            LEFT JOIN core.dim_date dc ON dc.full_date = d.closed_dt
        )
        INSERT INTO core.fact_claims WITH (TABLOCK)
        (
            claim_id,
            policy_key, customer_key, product_key,
            loss_date_key, reported_date_key, closed_date_key,
            claim_status, claim_type, claim_severity,
            claim_amount, approved_amount, payout_amount,
            deductible_amount, fraud_flag
        )
        SELECT
            CONCAT('CLM', RIGHT('000000000000' + CAST(seq AS VARCHAR(12)), 12)),
            policy_key, customer_key, product_key,
            loss_date_key, reported_date_key, closed_date_key,

            CASE WHEN closed_date_key IS NULL THEN 'Open' ELSE 'Closed' END,
            'Accident',
            CASE WHEN seq % 100 < 80 THEN 'Low' ELSE 'High' END,

            sum_insured * 0.05,
            sum_insured * 0.04,
            CASE WHEN closed_date_key IS NULL THEN 0 ELSE sum_insured * 0.03 END,
            500,
            IIF(seq % 50 = 0, 1, 0)
        FROM k;

        SET @start = @end + 1;
    END;

    -----------------------------------------------------------
    -- 4) CREATE INDEXES AFTER LOAD (FAST)
    -----------------------------------------------------------
    CREATE UNIQUE INDEX UX_fact_claims_claim_id
    ON core.fact_claims(claim_id);

    CREATE INDEX IX_fact_claims_policy_key
    ON core.fact_claims(policy_key);

    CREATE INDEX IX_fact_claims_loss_date_key
    ON core.fact_claims(loss_date_key);

    CREATE INDEX IX_fact_claims_status
    ON core.fact_claims(claim_status);

    -----------------------------------------------------------
    -- 5) Validation
    -----------------------------------------------------------
    SELECT COUNT(*) AS total_rows FROM core.fact_claims;

    SELECT claim_status, COUNT(*) cnt
    FROM core.fact_claims
    GROUP BY claim_status;

    SELECT TOP 10 * FROM core.fact_claims;
