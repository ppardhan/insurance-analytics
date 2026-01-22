/* =========================================================
   Step: Add & Populate product_key in core.dim_policy
   DB  : insurance_DB
   Why : Star schema joins should use keys (product_key), not text
========================================================= */

USE insurance_DB;
GO

-----------------------------------------------------------
-- 0) Safety checks (fail fast)
-----------------------------------------------------------
IF OBJECT_ID('core.dim_policy','U') IS NULL
    THROW 50020, 'Missing table: core.dim_policy', 1;

IF OBJECT_ID('core.dim_product','U') IS NULL
    THROW 50021, 'Missing table: core.dim_product', 1;

IF COL_LENGTH('core.dim_policy', 'product_line') IS NULL
    THROW 50022, 'Missing column: core.dim_policy.product_line', 1;

IF COL_LENGTH('core.dim_policy', 'policy_type') IS NULL
    THROW 50023, 'Missing column: core.dim_policy.policy_type', 1;

IF COL_LENGTH('core.dim_product', 'product_line') IS NULL
    THROW 50024, 'Missing column: core.dim_product.product_line', 1;

IF COL_LENGTH('core.dim_product', 'product_type') IS NULL
    THROW 50025, 'Missing column: core.dim_product.product_type', 1;

-----------------------------------------------------------
-- 1) Add product_key column if missing
-----------------------------------------------------------
IF COL_LENGTH('core.dim_policy', 'product_key') IS NULL
BEGIN
    ALTER TABLE core.dim_policy
    ADD product_key INT NULL;
END;
GO

-----------------------------------------------------------
-- 2) Populate product_key using (product_line + policy_type)
--    Deterministic mapping: lowest product_key per combo
-----------------------------------------------------------
;WITH map AS (
    SELECT
        product_line,
        product_type,
        MIN(product_key) AS product_key
    FROM core.dim_product
    GROUP BY product_line, product_type
)
UPDATE p
SET p.product_key = m.product_key
FROM core.dim_policy p
JOIN map m
  ON p.product_line = m.product_line
 AND p.policy_type  = m.product_type;
GO

-----------------------------------------------------------
-- 3) Validations (must be 0 / 0)
-----------------------------------------------------------

-- 3.1 Any policies still missing product_key?
SELECT COUNT(*) AS MissingProductKey
FROM core.dim_policy
WHERE product_key IS NULL;

-- 3.2 Any invalid product_key values?
SELECT COUNT(*) AS InvalidProductKey
FROM core.dim_policy p
LEFT JOIN core.dim_product d
  ON p.product_key = d.product_key
WHERE p.product_key IS NOT NULL
  AND d.product_key IS NULL;

-- 3.3 Preview
SELECT TOP 10
    p.policy_key, p.policy_id, p.product_line, p.policy_type, p.product_key
FROM core.dim_policy p
ORDER BY p.policy_key;
GO
