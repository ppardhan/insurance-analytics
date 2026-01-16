USE insurance_DB;
GO

/* Purpose: Helper numbers table for generating millions of rows */

-- Drop if exists (safe re-run)
IF OBJECT_ID('stg.helper_numbers','U') IS NOT NULL
DROP TABLE stg.helper_numbers;

GO

CREATE TABLE stg.helper_numbers(
    n INT NOT NULL PRIMARY KEY
);
GO

-- Insert numbers from 1 to 50,000,000

;WITH
E1(N) AS (SELECT 1 FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) a(n)), -- 10
E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),                                  -- 100
E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),                                  -- 10,000
E8(N) AS (SELECT 1 FROM E4 a CROSS JOIN E4 b),                                  -- 100,000,000
Nums AS (
    SELECT TOP(50000000)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL )) AS n
    FROM E8 )

    INSERT INTO stg.helper_numbers (n)
SELECT n
FROM Nums;
GO