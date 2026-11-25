-- Create DimDate in Fabric Warehouse

CREATE TABLE dbo.DimDate AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_date];

-- Step 2: Validate DimDate row count

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS row_count
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_date]

UNION ALL

SELECT
    'Warehouse' AS source,
    COUNT(*) AS row_count
FROM dbo.DimDate;


-- Step 3: Create DimZone in Fabric Warehouse

CREATE TABLE dbo.DimZone AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_zone];

-- Step 4: Validate DimZone

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT LocationID) AS unique_zones,
    SUM(CASE WHEN LocationID IS NULL THEN 1 ELSE 0 END)
        AS null_keys
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_zone]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),
    COUNT(DISTINCT LocationID),
    SUM(CASE WHEN LocationID IS NULL THEN 1 ELSE 0 END)
FROM dbo.DimZone;

-- Step 5: Create FactTaxiDaily in Warehouse

CREATE TABLE dbo.FactTaxiDaily AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready];

-- Step 6: Validate FactTaxiDaily

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), trip_date, 23),
        '|',
        CAST(PULocationID AS VARCHAR(20))
    )) AS unique_date_zone_pairs,
    SUM(
        CASE
            WHEN trip_date IS NULL OR PULocationID IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_keys
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),
    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), trip_date, 23),
        '|',
        CAST(PULocationID AS VARCHAR(20))
    )),
    SUM(
        CASE
            WHEN trip_date IS NULL OR PULocationID IS NULL
            THEN 1 ELSE 0
        END
    )
FROM dbo.FactTaxiDaily;

-- Step 7: Validate Fact-to-Dimension Relationships

SELECT
    COUNT(*) AS total_fact_rows,

    SUM(
        CASE WHEN d.[date] IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_date,

    SUM(
        CASE WHEN z.LocationID IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_zone

FROM dbo.FactTaxiDaily AS f

LEFT JOIN dbo.DimDate AS d
    ON f.trip_date = d.[date]

LEFT JOIN dbo.DimZone AS z
    ON f.PULocationID = z.LocationID;


-- Step 8: Create FactAirQualityDaily

CREATE TABLE dbo.FactAirQualityDaily AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily];

-- Step 9: Validate FactAirQualityDaily

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), measurement_date, 23),
        '|',
        CAST(sensor_id AS VARCHAR(30))
    )) AS unique_date_sensor_pairs,
    SUM(
        CASE
            WHEN measurement_date IS NULL OR sensor_id IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_keys
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),
    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), measurement_date, 23),
        '|',
        CAST(sensor_id AS VARCHAR(30))
    )),
    SUM(
        CASE
            WHEN measurement_date IS NULL OR sensor_id IS NULL
            THEN 1 ELSE 0
        END
    )
FROM dbo.FactAirQualityDaily;

-- Step 10: Validate Air Quality -> DimDate relationship

SELECT
    COUNT(*) AS total_fact_rows,

    SUM(
        CASE
            WHEN d.[date] IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_dim_date

FROM dbo.FactAirQualityDaily AS f

LEFT JOIN dbo.DimDate AS d
    ON f.measurement_date = d.[date];


-- Step 11: Create DimFX in Fabric Warehouse

CREATE TABLE dbo.DimFX AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily];

-- Step 12: Validate DimFX

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT rate_date) AS unique_dates,
    SUM(
        CASE
            WHEN rate_date IS NULL OR usd_per_eur IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_values
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),
    COUNT(DISTINCT rate_date),
    SUM(
        CASE
            WHEN rate_date IS NULL OR usd_per_eur IS NULL
            THEN 1 ELSE 0
        END
    )
FROM dbo.DimFX;

-- Step 13: Validate DimFX -> DimDate relationship

SELECT
    COUNT(*) AS total_fx_rows,

    SUM(
        CASE
            WHEN d.[date] IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_dim_date

FROM dbo.DimFX AS f

LEFT JOIN dbo.DimDate AS d
    ON f.rate_date = d.[date];



-- Step 14: Create DimGDP in Fabric Warehouse

CREATE TABLE dbo.DimGDP AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual];

-- Step 15: Validate DimGDP

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,

    COUNT(DISTINCT CONCAT(
        country, '|', CAST(year AS VARCHAR(10))
    )) AS unique_country_year_pairs,

    SUM(
        CASE
            WHEN country IS NULL
              OR year IS NULL
              OR gdp_usd IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_values

FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),

    COUNT(DISTINCT CONCAT(
        country, '|', CAST(year AS VARCHAR(10))
    )),

    SUM(
        CASE
            WHEN country IS NULL
              OR year IS NULL
              OR gdp_usd IS NULL
            THEN 1 ELSE 0
        END
    )

FROM dbo.DimGDP;

-- Step 16: Create DimEPAStation

CREATE TABLE dbo.DimEPAStation AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station];

-- Step 17: Validate DimEPAStation

SELECT
    COUNT(*) AS total_stations,

    COUNT(DISTINCT s.station_id) AS unique_stations,

    SUM(
        CASE
            WHEN s.station_id IS NULL
              OR s.LocationID IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_keys,

    SUM(
        CASE
            WHEN z.LocationID IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_dim_zone

FROM dbo.DimEPAStation AS s

LEFT JOIN dbo.DimZone AS z
    ON s.LocationID = z.LocationID;

-- Step 18: Create FactEPANO2Hourly

CREATE TABLE dbo.FactEPANO2Hourly AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly];

-- Step 19: Validate FactEPANO2Hourly

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,

    COUNT(DISTINCT CONCAT(
        station_id, '|',
        CONVERT(VARCHAR(10), measurement_date_ny, 23), '|',
        CAST(hour_ny AS VARCHAR(2))
    )) AS unique_keys,

    SUM(
        CASE
            WHEN station_id IS NULL
              OR measurement_date_ny IS NULL
              OR hour_ny IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_keys

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),

    COUNT(DISTINCT CONCAT(
        station_id, '|',
        CONVERT(VARCHAR(10), measurement_date_ny, 23), '|',
        CAST(hour_ny AS VARCHAR(2))
    )),

    SUM(
        CASE
            WHEN station_id IS NULL
              OR measurement_date_ny IS NULL
              OR hour_ny IS NULL
            THEN 1 ELSE 0
        END
    )

FROM dbo.FactEPANO2Hourly;

-- Step 20: Validate EPA Hourly relationships

SELECT
    COUNT(*) AS total_fact_rows,

    SUM(
        CASE WHEN s.station_id IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_station,

    SUM(
        CASE WHEN d.[date] IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_date

FROM dbo.FactEPANO2Hourly AS f

LEFT JOIN dbo.DimEPAStation AS s
    ON f.station_id = s.station_id

LEFT JOIN dbo.DimDate AS d
    ON f.measurement_date_ny = d.[date];


-- Step 21: Create FactTaxiHourly

CREATE TABLE dbo.FactTaxiHourly AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly];

-- Step 22: Validate FactTaxiHourly

SELECT
    'Lakehouse' AS source,
    COUNT(*) AS total_rows,

    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), pickup_date_ny, 23), '|',
        CAST(hour_ny AS VARCHAR(2)), '|',
        CAST(PULocationID AS VARCHAR(20))
    )) AS unique_keys,

    SUM(
        CASE
            WHEN pickup_date_ny IS NULL
              OR hour_ny IS NULL
              OR PULocationID IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_keys

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly]

UNION ALL

SELECT
    'Warehouse',
    COUNT(*),

    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), pickup_date_ny, 23), '|',
        CAST(hour_ny AS VARCHAR(2)), '|',
        CAST(PULocationID AS VARCHAR(20))
    )),

    SUM(
        CASE
            WHEN pickup_date_ny IS NULL
              OR hour_ny IS NULL
              OR PULocationID IS NULL
            THEN 1 ELSE 0
        END
    )

FROM dbo.FactTaxiHourly;

-- Step 24: Validate FactTaxiHourly relationships

SELECT
    COUNT(*) AS total_fact_rows,

    SUM(
        CASE WHEN d.[date] IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_date,

    SUM(
        CASE WHEN z.LocationID IS NULL
        THEN 1 ELSE 0 END
    ) AS missing_dim_zone

FROM dbo.FactTaxiHourly AS f

LEFT JOIN dbo.DimDate AS d
    ON f.pickup_date_ny = d.[date]

LEFT JOIN dbo.DimZone AS z
    ON f.PULocationID = z.LocationID;

-- Step 25: Create FactNO2Daily in Fabric Warehouse

CREATE TABLE dbo.FactNO2Daily AS
SELECT *
FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily];

-- Step 26: Validate FactNO2Daily

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT f.measurement_date) AS unique_dates,

    SUM(
        CASE
            WHEN f.measurement_date IS NULL
              OR f.avg_no2_ppm IS NULL
            THEN 1 ELSE 0
        END
    ) AS null_values,

    SUM(
        CASE
            WHEN d.[date] IS NULL
            THEN 1 ELSE 0
        END
    ) AS missing_dim_date

FROM dbo.FactNO2Daily AS f

LEFT JOIN dbo.DimDate AS d
    ON f.measurement_date = d.[date];

-- Step 27: List Warehouse Physical Tables

SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;