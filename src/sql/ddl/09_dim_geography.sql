/* =========================================================
   DIMENSION: core.dim_geography (END-to-END)
   Database : insurance_DB
   Grain    : 1 row per geography (City level)
   Target   : 50,000 cities (synthetic, scalable)
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

IF OBJECT_ID('stg.helper_numbers','U') IS NULL
BEGIN
    RAISERROR('Table stg.helper_numbers does not exist.', 16, 1);
    RETURN;
END;

-----------------------------------------------------------
-- 1) Parameters
-----------------------------------------------------------
DECLARE @geo_rows INT = 50000;

-----------------------------------------------------------
-- 2) DDL
-----------------------------------------------------------
IF OBJECT_ID('core.dim_geography','U') IS NOT NULL
    DROP TABLE core.dim_geography;

CREATE TABLE core.dim_geography (
    geography_key     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    geography_id      VARCHAR(30)  NOT NULL,
    country           VARCHAR(30)  NOT NULL,
    region            VARCHAR(30)  NOT NULL,   -- North/South/East/West/Central
    state_name        VARCHAR(50)  NOT NULL,
    city_name         VARCHAR(80)  NOT NULL,
    pincode           VARCHAR(10)  NOT NULL,
    city_tier         VARCHAR(10)  NOT NULL,   -- Tier1/Tier2/Tier3
    is_metro          BIT          NOT NULL,
    created_at        DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_geography_geography_id
ON core.dim_geography(geography_id);

-----------------------------------------------------------
-- 3) DML (deterministic + realistic-ish)
-----------------------------------------------------------
;WITH base AS (
    SELECT TOP (@geo_rows) n.n AS seq
    FROM stg.helper_numbers n
    ORDER BY n.n
),
r AS (
    SELECT
        seq,
        CASE (seq % 5)
            WHEN 0 THEN 'North'
            WHEN 1 THEN 'South'
            WHEN 2 THEN 'East'
            WHEN 3 THEN 'West'
            ELSE 'Central'
        END AS region
    FROM base
),
s AS (
    SELECT
        r.seq,
        r.region,
        -- simple synthetic states per region
        CASE r.region
            WHEN 'North'   THEN CONCAT('State_N_', (r.seq % 12) + 1)
            WHEN 'South'   THEN CONCAT('State_S_', (r.seq % 10) + 1)
            WHEN 'East'    THEN CONCAT('State_E_', (r.seq %  8) + 1)
            WHEN 'West'    THEN CONCAT('State_W_', (r.seq %  9) + 1)
            ELSE                CONCAT('State_C_', (r.seq %  7) + 1)
        END AS state_name
    FROM r
)
INSERT INTO core.dim_geography (
    geography_id, country, region, state_name, city_name, pincode, city_tier, is_metro
)
SELECT
    CONCAT('GEO', RIGHT('000000' + CAST(s.seq AS VARCHAR(6)), 6)) AS geography_id,
    'India' AS country,
    s.region,
    s.state_name,
    CONCAT('City_', s.state_name, '_', RIGHT('00000' + CAST(s.seq AS VARCHAR(5)), 5)) AS city_name,

    -- PIN style (not real pin mapping, but realistic format)
    RIGHT('000000' + CAST(100000 + (s.seq % 900000) AS VARCHAR(6)), 6) AS pincode,

    CASE
        WHEN (s.seq % 100) < 25 THEN 'Tier1'  -- 25%
        WHEN (s.seq % 100) < 65 THEN 'Tier2'  -- 40%
        ELSE 'Tier3'                          -- 35%
    END AS city_tier,

    CASE WHEN (s.seq % 100) < 18 THEN 1 ELSE 0 END AS is_metro -- ~18%
FROM s;

-----------------------------------------------------------
-- 4) Validations
-----------------------------------------------------------

SELECT COUNT(*) AS GeographyRowCount
FROM core.dim_geography;

SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_geography');

SELECT COUNT(*) AS DuplicateGeographyIds
FROM (
    SELECT geography_id
    FROM core.dim_geography
    GROUP BY geography_id
    HAVING COUNT(*) > 1
) d;

SELECT city_tier, COUNT(*) AS cnt
FROM core.dim_geography
GROUP BY city_tier
ORDER BY cnt DESC;

SELECT TOP 10 *
FROM core.dim_geography
ORDER BY geography_key;
