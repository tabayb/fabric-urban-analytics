-- =====================================================
-- Project: Fabric Urban Analytics
-- Module: Warehouse SCD Type 2
-- Source: dbo.DimZone
-- Target: dbo.DimZoneSCD2
-- =====================================================


-- 01. SOURCE VALIDATION

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT LocationID) AS unique_keys,
    COUNT(*) - COUNT(LocationID) AS null_keys
FROM dbo.DimZone;

IF EXISTS (
    SELECT LocationID
    FROM dbo.DimZone
    GROUP BY LocationID
    HAVING COUNT(*) > 1 OR LocationID IS NULL
)
BEGIN
    THROW 50001, 'Invalid source business keys', 1;
END;


-- 02. CREATE TARGET TABLE

IF OBJECT_ID('dbo.DimZoneSCD2', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimZoneSCD2 (
        zone_sk BIGINT NOT NULL,
        LocationID INT NOT NULL,
        Borough VARCHAR(8000),
        Zone VARCHAR(8000),
        service_zone VARCHAR(8000),
        row_hash VARBINARY(32) NOT NULL,
        effective_from DATETIME2(6) NOT NULL,
        effective_to DATETIME2(6) NULL,
        is_current BIT NOT NULL
    );
END;


-- 03. INITIAL LOAD

DECLARE @load_time DATETIME2(6) = SYSUTCDATETIME();

IF NOT EXISTS (SELECT 1 FROM dbo.DimZoneSCD2)
BEGIN
    INSERT INTO dbo.DimZoneSCD2 (
        zone_sk,
        LocationID,
        Borough,
        Zone,
        service_zone,
        row_hash,
        effective_from,
        effective_to,
        is_current
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY LocationID),
        LocationID,
        Borough,
        Zone,
        service_zone,
        CONVERT(VARBINARY(32), HASHBYTES('SHA2_256', CONCAT(
            CAST('' AS VARCHAR(MAX)),
            COALESCE(CAST(DATALENGTH(Borough) AS VARCHAR(10)), '-1'),
            ':', Borough,
            COALESCE(CAST(DATALENGTH(Zone) AS VARCHAR(10)), '-1'),
            ':', Zone,
            COALESCE(CAST(DATALENGTH(service_zone) AS VARCHAR(10)), '-1'),
            ':', service_zone
        ))),
        @load_time,
        NULL,
        1
    FROM dbo.DimZone;
END;


-- 04. STAGING AND HASHING

DROP TABLE IF EXISTS #stg_zone;

CREATE TABLE #stg_zone (
    LocationID INT NOT NULL,
    Borough VARCHAR(8000),
    Zone VARCHAR(8000),
    service_zone VARCHAR(8000),
    row_hash VARBINARY(32)
)
WITH (DISTRIBUTION = ROUND_ROBIN);

-- Simulate a source attribute change

INSERT INTO #stg_zone (
    LocationID,
    Borough,
    Zone,
    service_zone
)
SELECT
    LocationID,
    Borough,
    CASE
        WHEN LocationID = 1
        THEN 'Newark Airport Terminal'
        ELSE Zone
    END,
    service_zone
FROM dbo.DimZone;

-- Calculate SHA-256

UPDATE #stg_zone
SET row_hash = CONVERT(VARBINARY(32),
    HASHBYTES('SHA2_256', CONCAT(
        CAST('' AS VARCHAR(MAX)),
        COALESCE(CAST(DATALENGTH(Borough) AS VARCHAR(10)), '-1'),
        ':', Borough,
        COALESCE(CAST(DATALENGTH(Zone) AS VARCHAR(10)), '-1'),
        ':', Zone,
        COALESCE(CAST(DATALENGTH(service_zone) AS VARCHAR(10)), '-1'),
        ':', service_zone
    ))
);


-- 05. CHANGE DETECTION

SELECT
    s.LocationID,
    t.zone_sk AS old_sk,
    t.Zone AS old_zone,
    s.Zone AS new_zone
FROM #stg_zone AS s
INNER JOIN dbo.DimZoneSCD2 AS t
    ON s.LocationID = t.LocationID
WHERE t.is_current = 1
    AND s.row_hash <> t.row_hash;


-- 06. SCD TYPE 2 TRANSACTION

DECLARE @change_time DATETIME2(6) = SYSUTCDATETIME();
DECLARE @max_sk BIGINT;

BEGIN TRY

    BEGIN TRANSACTION;

    -- Get maximum surrogate key

    SELECT @max_sk = COALESCE(MAX(zone_sk), 0)
    FROM dbo.DimZoneSCD2;

    -- Expire changed records

    UPDATE dbo.DimZoneSCD2
    SET
        effective_to = @change_time,
        is_current = 0
    WHERE is_current = 1
      AND zone_sk IN (
          SELECT t.zone_sk
          FROM dbo.DimZoneSCD2 AS t
          INNER JOIN #stg_zone AS s
              ON t.LocationID = s.LocationID
          WHERE t.is_current = 1
              AND t.row_hash <> s.row_hash
      );

    -- Insert new versions and new business keys

    INSERT INTO dbo.DimZoneSCD2 (
        zone_sk,
        LocationID,
        Borough,
        Zone,
        service_zone,
        row_hash,
        effective_from,
        effective_to,
        is_current
    )
    SELECT
        @max_sk + ROW_NUMBER() OVER (ORDER BY s.LocationID),
        s.LocationID,
        s.Borough,
        s.Zone,
        s.service_zone,
        s.row_hash,
        @change_time,
        NULL,
        1
    FROM #stg_zone AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.DimZoneSCD2 AS t
        WHERE t.LocationID = s.LocationID
            AND t.is_current = 1
    );

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;


-- 07. DATA QUALITY VALIDATION

-- 7.1 Historical versions

SELECT
    zone_sk,
    LocationID,
    Zone,
    effective_from,
    effective_to,
    is_current
FROM dbo.DimZoneSCD2
WHERE LocationID = 1
ORDER BY zone_sk;


-- 7.2 Record counts

SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END)
        AS current_records,
    SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
        AS historical_records
FROM dbo.DimZoneSCD2;


-- 7.3 Duplicate surrogate keys

SELECT
    zone_sk,
    COUNT(*) AS duplicate_count
FROM dbo.DimZoneSCD2
GROUP BY zone_sk
HAVING COUNT(*) > 1;


-- 7.4 Exactly one active version per business key

SELECT
    LocationID,
    SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END)
        AS active_versions
FROM dbo.DimZoneSCD2
GROUP BY LocationID
HAVING SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END) <> 1;


-- 7.5 Invalid effective dates

SELECT *
FROM dbo.DimZoneSCD2
WHERE
    (is_current = 1 AND effective_to IS NOT NULL)
    OR
    (is_current = 0 AND effective_to IS NULL)
    OR
    (effective_to <= effective_from);


-- 08. CLEANUP

DROP TABLE IF EXISTS #stg_zone;


