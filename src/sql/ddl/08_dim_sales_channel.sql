/* =========================================================
   DIMENSION: core.dim_sales_channel (END-to-END)
   Database : insurance_DB
   Grain    : 1 row per sales channel
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
IF OBJECT_ID('core.dim_sales_channel','U') IS NOT NULL
    DROP TABLE core.dim_sales_channel;

CREATE TABLE core.dim_sales_channel (
    sales_channel_key   INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sales_channel_code  VARCHAR(30)  NOT NULL,
    sales_channel_name  VARCHAR(60)  NOT NULL,

    channel_group       VARCHAR(30)  NOT NULL,  -- Offline/Online/Partner
    sub_channel         VARCHAR(30)  NOT NULL,  -- Agency/Broker/Bank/Digital/Corporate/etc.
    commission_model    VARCHAR(30)  NOT NULL,  -- Flat/Slab/Hybrid
    is_active           BIT          NOT NULL,

    created_at          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_sales_channel_code
ON core.dim_sales_channel(sales_channel_code);

-----------------------------------------------------------
-- 2) DML (small controlled dimension - hardcoded seed)
-----------------------------------------------------------
INSERT INTO core.dim_sales_channel (
    sales_channel_code, sales_channel_name,
    channel_group, sub_channel, commission_model, is_active
)
VALUES
('SC_AGENCY',   'Agency',          'Offline', 'Agency',        'Slab',   1),
('SC_BROKER',   'Broker',          'Partner', 'Broker',        'Slab',   1),
('SC_BANK',     'Bancassurance',   'Partner', 'Bank',          'Hybrid', 1),
('SC_DIGITAL',  'Digital Direct',  'Online',  'Digital',       'Flat',   1),
('SC_CORP',     'Corporate Sales', 'Offline', 'Corporate',     'Hybrid', 1),
('SC_TPA',      'TPA',             'Partner', 'TPA',           'Flat',   1),
('SC_TELE',     'Tele Sales',      'Online',  'Telecalling',   'Flat',   1),
('SC_POSP',     'POSP',            'Online',  'POSP',          'Slab',   1);

-----------------------------------------------------------
-- 3) Validations
-----------------------------------------------------------

-- Row count (expected 8)
SELECT COUNT(*) AS SalesChannelRowCount
FROM core.dim_sales_channel;

-- Column count
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_sales_channel');

-- Duplicate codes (must be 0)
SELECT COUNT(*) AS DuplicateSalesChannelCodes
FROM (
    SELECT sales_channel_code
    FROM core.dim_sales_channel
    GROUP BY sales_channel_code
    HAVING COUNT(*) > 1
) d;

-- Preview
SELECT TOP 10 *
FROM core.dim_sales_channel
ORDER BY sales_channel_key;
