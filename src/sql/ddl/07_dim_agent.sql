/* =========================================================
   DIMENSION: core.dim_agent (END-to-END)
   Database : insurance_DB
   Grain    : 1 row per insurance agent
   Target   : 200,000 agents
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
-- 1) Parameters (NO GO after this)
-----------------------------------------------------------
DECLARE @agent_rows INT = 200000;

-----------------------------------------------------------
-- 2) DDL
-----------------------------------------------------------
IF OBJECT_ID('core.dim_agent','U') IS NOT NULL
    DROP TABLE core.dim_agent;

CREATE TABLE core.dim_agent (
    agent_key          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    agent_id           VARCHAR(30)  NOT NULL,
    agent_code         VARCHAR(30)  NOT NULL,
    agent_name         VARCHAR(120) NOT NULL,

    agent_type         VARCHAR(20)  NOT NULL,   -- Individual/Corporate
    channel            VARCHAR(30)  NOT NULL,   -- Agency/Bancassurance/Broker/Digital
    license_status     VARCHAR(20)  NOT NULL,   -- Active/Suspended/Expired
    joining_date_key   INT          NOT NULL,   -- FK to core.dim_date

    region             VARCHAR(30)  NOT NULL,   -- North/South/East/West/Central
    city_tier          VARCHAR(10)  NOT NULL,   -- Tier1/Tier2/Tier3
    performance_band   VARCHAR(10)  NOT NULL,   -- A/B/C/D

    is_active          BIT          NOT NULL,
    created_at         DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

CREATE UNIQUE INDEX UX_dim_agent_agent_id   ON core.dim_agent(agent_id);
CREATE UNIQUE INDEX UX_dim_agent_agent_code ON core.dim_agent(agent_code);

-----------------------------------------------------------
-- 3) DML (deterministic + realistic distributions)
-----------------------------------------------------------
;WITH base AS (
    SELECT TOP (@agent_rows) n.n AS seq
    FROM stg.helper_numbers n
    ORDER BY n.n
),
dates AS (
    SELECT
        b.seq,
        d.date_key AS joining_date_key
    FROM base b
    JOIN core.dim_date d
      ON d.full_date = DATEADD(DAY, (b.seq % 3650), '2018-01-01') -- 2018..~2027
)
INSERT INTO core.dim_agent (
    agent_id, agent_code, agent_name,
    agent_type, channel, license_status, joining_date_key,
    region, city_tier, performance_band,
    is_active
)
SELECT
    CONCAT('AGT', RIGHT('000000' + CAST(b.seq AS VARCHAR(6)), 6)) AS agent_id,
    CONCAT('AC',  RIGHT('000000' + CAST(b.seq AS VARCHAR(6)), 6)) AS agent_code,
    CONCAT('Agent ', RIGHT('000000' + CAST(b.seq AS VARCHAR(6)), 6)) AS agent_name,

    CASE WHEN (b.seq % 100) < 88 THEN 'Individual' ELSE 'Corporate' END AS agent_type,

    CASE
        WHEN (b.seq % 100) < 55 THEN 'Agency'         -- 55%
        WHEN (b.seq % 100) < 75 THEN 'Bancassurance'  -- 20%
        WHEN (b.seq % 100) < 90 THEN 'Broker'         -- 15%
        ELSE 'Digital'                                -- 10%
    END AS channel,

    CASE
        WHEN (b.seq % 1000) < 930 THEN 'Active'       -- 93%
        WHEN (b.seq % 1000) < 970 THEN 'Suspended'    -- 4%
        ELSE 'Expired'                                 -- 3%
    END AS license_status,

    dt.joining_date_key,

    CASE (b.seq % 5)
        WHEN 0 THEN 'North'
        WHEN 1 THEN 'South'
        WHEN 2 THEN 'East'
        WHEN 3 THEN 'West'
        ELSE 'Central'
    END AS region,

    CASE
        WHEN (b.seq % 100) < 35 THEN 'Tier1'  -- 35%
        WHEN (b.seq % 100) < 70 THEN 'Tier2'  -- 35%
        ELSE 'Tier3'                          -- 30%
    END AS city_tier,

    CASE
        WHEN (b.seq % 100) < 20 THEN 'A'      -- 20%
        WHEN (b.seq % 100) < 55 THEN 'B'      -- 35%
        WHEN (b.seq % 100) < 85 THEN 'C'      -- 30%
        ELSE 'D'                               -- 15%
    END AS performance_band,

    CASE WHEN (b.seq % 100) < 92 THEN 1 ELSE 0 END AS is_active  -- 92%
FROM base b
JOIN dates dt
  ON dt.seq = b.seq;

-----------------------------------------------------------
-- 4) Validations
-----------------------------------------------------------

-- Row count
SELECT COUNT(*) AS AgentRowCount
FROM core.dim_agent;

-- Column count
SELECT COUNT(*) AS ColumnCount
FROM sys.columns
WHERE object_id = OBJECT_ID('core.dim_agent');

-- Duplicate checks (must be 0)
SELECT COUNT(*) AS DuplicateAgentIds
FROM (
    SELECT agent_id FROM core.dim_agent
    GROUP BY agent_id HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS DuplicateAgentCodes
FROM (
    SELECT agent_code FROM core.dim_agent
    GROUP BY agent_code HAVING COUNT(*) > 1
) d;

-- Date key integrity (must be 0)
SELECT COUNT(*) AS InvalidJoiningDateKeys
FROM core.dim_agent a
LEFT JOIN core.dim_date d ON a.joining_date_key = d.date_key
WHERE d.date_key IS NULL;

-- Distribution checks
SELECT channel, COUNT(*) AS cnt
FROM core.dim_agent
GROUP BY channel
ORDER BY cnt DESC;

SELECT performance_band, COUNT(*) AS cnt
FROM core.dim_agent
GROUP BY performance_band
ORDER BY cnt DESC;

-- Preview
SELECT TOP 10 *
FROM core.dim_agent
ORDER BY agent_key;
