USE insurance_DB;
GO

-- Safety: confirm table exists
IF OBJECT_ID('stg.helper_numbers','U') IS NULL
BEGIN
    RAISERROR('stg.helper_numbers does not exist.', 16, 1);
    RETURN;
END
GO

-- Refill only if empty
IF (SELECT COUNT(*) FROM stg.helper_numbers) = 0
BEGIN
    ;WITH
    E1(N) AS (SELECT 1 FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) a(n)), -- 10
    E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),                                  -- 100
    E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),                                  -- 10,000
    E8(N) AS (SELECT 1 FROM E4 a CROSS JOIN E4 b),                                  -- 100,000,000
    Nums AS (
        SELECT TOP (50000000)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM E8
    )
    INSERT INTO stg.helper_numbers (n)
    SELECT n
    FROM Nums;
END
GO

-- Verify
SELECT COUNT(*) AS helper_rows FROM stg.helper_numbers;
GO

SELECT  * from stg.helper_numbers;