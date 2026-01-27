/* =========================================================
   DIMENSION: core.dim_claim_status (END-to-END)
   Database : insurance_DB
   Grain    : 1 row per claim status
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

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='core')
BEGIN
    RAISERROR('Schema core does not exist.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) DDL
-----------------------------------------------------------
IF OBJECT_ID('core.dim_claim_status','U') IS NOT NULL
    DROP TABLE core.dim_claim_status;

CREATE TABLE core.dim_claim_status (
    claim_status_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    claim_status_code   VARCHAR(30)  NOT NULL,
    claim_status_name   VARCHAR(30)  NOT NULL,
    status_group        VARCHAR(30)  NOT NULL,  -- Open/Closed/InProgress
    is_final            BIT          NOT NULL,
    created_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_claim_status_code
ON core.dim_claim_status(claim_status_code);

-----------------------------------------------------------
-- 2) DML (seed values)
-----------------------------------------------------------
INSERT INTO core.dim_claim_status (
    claim_status_code, claim_status_name, status_group, is_final
)
VALUES
('CLM_OPEN',         'Open',          'Open',       0),
('CLM_INVEST',       'Investigating', 'InProgress', 0),
('CLM_APPROVED',     'Approved',      'InProgress', 0),
('CLM_REJECTED',     'Rejected',      'Closed',     1),
('CLM_SETTLED',      'Settled',       'Closed',     1),
('CLM_WITHDRAWN',    'Withdrawn',     'Closed',     1);

-----------------------------------------------------------
-- 3) Validations
-----------------------------------------------------------
SELECT COUNT(*) AS ClaimStatusRowCount
FROM core.dim_claim_status;

SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_claim_status');

SELECT COUNT(*) AS DuplicateClaimStatusCodes
FROM (
    SELECT claim_status_code
    FROM core.dim_claim_status
    GROUP BY claim_status_code
    HAVING COUNT(*) > 1
) d;

SELECT TOP 10 *
FROM core.dim_claim_status
ORDER BY claim_status_key;
