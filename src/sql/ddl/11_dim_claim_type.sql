USE insurance_DB;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- DDL
IF OBJECT_ID('core.dim_claim_type','U') IS NOT NULL
    DROP TABLE core.dim_claim_type;

CREATE TABLE core.dim_claim_type (
    claim_type_key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    claim_type_code    VARCHAR(30)  NOT NULL,
    claim_type_name    VARCHAR(50)  NOT NULL,
    product_line       VARCHAR(30)  NOT NULL,  -- Motor/Health/Life/Home/Travel/SME
    severity_hint      VARCHAR(20)  NOT NULL,  -- Low/Medium/High/Catastrophic
    created_at         DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_claim_type_code
ON core.dim_claim_type(claim_type_code);

-- DML (seed - realistic coverage across product lines)
INSERT INTO core.dim_claim_type (claim_type_code, claim_type_name, product_line, severity_hint)
VALUES
('CT_MOTOR_ACC',   'Accident',        'Motor',  'Medium'),
('CT_MOTOR_THEFT', 'Theft',           'Motor',  'High'),
('CT_MOTOR_OD',    'Own Damage',      'Motor',  'Medium'),

('CT_HEALTH_MED',  'Medical',         'Health', 'Medium'),
('CT_HEALTH_IPD',  'Hospitalization', 'Health', 'High'),

('CT_LIFE_DEATH',  'Death',           'Life',   'High'),
('CT_LIFE_DIS',    'Disability',      'Life',   'High'),

('CT_HOME_FIRE',   'Fire',            'Home',   'High'),
('CT_HOME_FLOOD',  'Flood',           'Home',   'High'),
('CT_HOME_BURGL',  'Burglary',        'Home',   'Medium'),

('CT_TRAVEL_MED',  'Travel Medical',  'Travel', 'Medium'),
('CT_TRAVEL_LOSS', 'Baggage Loss',    'Travel', 'Low'),
('CT_TRAVEL_CAN',  'Trip Cancellation','Travel','Medium'),

('CT_SME_PROP',    'Property Damage', 'SME',    'High'),
('CT_SME_LIAB',    'Liability',       'SME',    'High');

-- Validations
SELECT COUNT(*) AS ClaimTypeRowCount
FROM core.dim_claim_type;

SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_claim_type');

SELECT COUNT(*) AS DuplicateClaimTypeCodes
FROM (
    SELECT claim_type_code
    FROM core.dim_claim_type
    GROUP BY claim_type_code
    HAVING COUNT(*) > 1
) d;

SELECT product_line, COUNT(*) AS cnt
FROM core.dim_claim_type
GROUP BY product_line
ORDER BY cnt DESC;

SELECT TOP 10 *
FROM core.dim_claim_type
ORDER BY claim_type_key;
