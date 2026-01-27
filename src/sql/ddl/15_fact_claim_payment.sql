USE insurance_DB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-----------------------------------------------------------
-- Recreate fact_claim_payment cleanly
-----------------------------------------------------------
IF OBJECT_ID('core.fact_claim_payment','U') IS NOT NULL
    DROP TABLE core.fact_claim_payment;
GO

CREATE TABLE core.fact_claim_payment (
    claim_payment_key   BIGINT IDENTITY(1,1) PRIMARY KEY,
    claim_key           BIGINT NOT NULL,
    policy_key          BIGINT NOT NULL,
    customer_key        BIGINT NOT NULL,
    product_key         INT    NOT NULL,
    payment_date_key    INT    NOT NULL,
    payment_method      VARCHAR(20) NOT NULL,
    payment_status      VARCHAR(20) NOT NULL,
    payment_amount      DECIMAL(14,2) NOT NULL,
    created_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);
GO

-----------------------------------------------------------
-- Insert payments from eligible claims (SAFE METHOD)
-----------------------------------------------------------
INSERT INTO core.fact_claim_payment (
    claim_key, policy_key, customer_key, product_key,
    payment_date_key, payment_method, payment_status, payment_amount
)
SELECT TOP (10000000)   -- target volume
    c.claim_key,
    c.policy_key,
    c.customer_key,
    c.product_key,

    -- payment date = within 0–30 days after closure
    d2.date_key AS payment_date_key,

    CASE
        WHEN c.claim_key % 100 < 45 THEN 'NEFT'
        WHEN c.claim_key % 100 < 70 THEN 'UPI'
        WHEN c.claim_key % 100 < 85 THEN 'IMPS'
        WHEN c.claim_key % 100 < 93 THEN 'Cheque'
        WHEN c.claim_key % 100 < 98 THEN 'Card'
        ELSE 'Cash'
    END AS payment_method,

    CASE
        WHEN c.claim_key % 1000 < 980 THEN 'Paid'
        WHEN c.claim_key % 1000 < 995 THEN 'Failed'
        ELSE 'Reversed'
    END AS payment_status,

    CAST(
        CASE (c.claim_key % 3)
            WHEN 0 THEN c.payout_amount * 1.00
            WHEN 1 THEN c.payout_amount * 0.60
            ELSE        c.payout_amount * 0.40
        END
    AS DECIMAL(14,2)) AS payment_amount

FROM core.fact_claims c
JOIN core.dim_date d1
    ON d1.date_key = c.closed_date_key
JOIN core.dim_date d2
    ON d2.full_date = DATEADD(DAY, c.claim_key % 31, d1.full_date)
WHERE c.payout_amount > 0
  AND c.closed_date_key IS NOT NULL;
GO

-----------------------------------------------------------
-- VALIDATIONS
-----------------------------------------------------------
SELECT COUNT(*) AS ClaimPaymentRowCount
FROM core.fact_claim_payment;

SELECT COUNT(*) AS InvalidClaimKeys
FROM core.fact_claim_payment p
LEFT JOIN core.fact_claims c ON p.claim_key = c.claim_key
WHERE c.claim_key IS NULL;

SELECT COUNT(*) AS InvalidPaymentDateKeys
FROM core.fact_claim_payment p
LEFT JOIN core.dim_date d ON p.payment_date_key = d.date_key
WHERE d.date_key IS NULL;

SELECT SUM(CASE WHEN payment_amount < 0 THEN 1 ELSE 0 END) AS NegativePayments
FROM core.fact_claim_payment;

SELECT TOP 10 *
FROM core.fact_claim_payment
ORDER BY claim_payment_key DESC;
GO
