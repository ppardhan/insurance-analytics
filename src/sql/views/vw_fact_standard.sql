USE insurance_DB;
GO

-----------------------------------------------------------
-- View 1: core.vw_fact_premium_txn  (standard name)
-----------------------------------------------------------
CREATE OR ALTER VIEW core.vw_fact_premium_txn
AS
SELECT
    policy_key,
    customer_key,
    product_key,
    premium_date_key,
    due_date_key,
    payment_frequency,
    payment_status,
    payment_method,
    gross_premium,
    discount_amount,
    tax_amount,
    net_premium,
    created_at
FROM core.fact_premium;
GO

-----------------------------------------------------------
-- View 2: core.vw_fact_claim (standard name)
-----------------------------------------------------------
CREATE OR ALTER VIEW core.vw_fact_claim
AS
SELECT
    claim_key,
    claim_id,
    policy_key,
    customer_key,
    product_key,
    loss_date_key,
    reported_date_key,
    closed_date_key,
    claim_status,
    claim_type,
    claim_severity,
    claim_amount,
    approved_amount,
    payout_amount,
    deductible_amount,
    fraud_flag,
    created_at
FROM core.fact_claims;
GO

-----------------------------------------------------------
-- Validations
-----------------------------------------------------------
SELECT COUNT(*) AS PremiumTxnRows FROM core.vw_fact_premium_txn;
SELECT COUNT(*) AS ClaimRows      FROM core.vw_fact_claim;

SELECT TOP 5 * FROM core.vw_fact_premium_txn ORDER BY created_at DESC;
SELECT TOP 5 * FROM core.vw_fact_claim       ORDER BY claim_key DESC;
GO
