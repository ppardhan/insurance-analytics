USE insurance_DB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- DDL
IF OBJECT_ID('core.dim_policy_status','U') IS NOT NULL
    DROP TABLE core.dim_policy_status;

CREATE TABLE core.dim_policy_status (
    policy_status_key    INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    policy_status_code   VARCHAR(30)  NOT NULL,
    policy_status_name   VARCHAR(30)  NOT NULL,
    is_active_policy     BIT          NOT NULL,   -- active in-force?
    is_terminal          BIT          NOT NULL,   -- terminal/end state?
    created_at           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_policy_status_code
ON core.dim_policy_status(policy_status_code);

-- DML (seed)
INSERT INTO core.dim_policy_status (policy_status_code, policy_status_name, is_active_policy, is_terminal)
VALUES
('POL_ACTIVE',     'Active',     1, 0),
('POL_LAPSED',     'Lapsed',     0, 1),
('POL_EXPIRED',    'Expired',    0, 1),
('POL_CANCELLED',  'Cancelled',  0, 1),
('POL_PENDING',    'Pending',    0, 0),
('POL_RENEWED',    'Renewed',    1, 0),
('POL_SUSPENDED',  'Suspended',  0, 0);

-- Validations
SELECT COUNT(*) AS PolicyStatusRowCount
FROM core.dim_policy_status;

SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_policy_status');

SELECT COUNT(*) AS DuplicatePolicyStatusCodes
FROM (
    SELECT policy_status_code
    FROM core.dim_policy_status
    GROUP BY policy_status_code
    HAVING COUNT(*) > 1
) d;

SELECT TOP 10 *
FROM core.dim_policy_status
ORDER BY policy_status_key;
