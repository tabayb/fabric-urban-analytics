SELECT TOP (10) *
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily];

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT rate_date) AS unique_dates,
    COUNT(*) - COUNT(DISTINCT rate_date) AS duplicate_or_null_dates,
    SUM(CASE WHEN rate_date IS NULL THEN 1 ELSE 0 END) AS null_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily];


SELECT COUNT(*) AS unmatched_fx_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily] AS fx
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
    ON fx.rate_date = d.[date]
WHERE d.[date] IS NULL;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT measurement_date) AS unique_dates,
    COUNT(*) - COUNT(DISTINCT measurement_date) AS duplicate_or_null_dates,
    SUM(CASE WHEN measurement_date IS NULL THEN 1 ELSE 0 END) AS null_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily];

SELECT COUNT(*) AS unmatched_no2_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily] AS n
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
    ON n.measurement_date = d.[date]
WHERE d.[date] IS NULL;

WITH grouped AS (
    SELECT
        measurement_date,
        sensor_id,
        COUNT(*) AS group_rows
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]
    GROUP BY measurement_date, sensor_id
)
SELECT
    SUM(group_rows) AS total_rows,
    COUNT(*) AS unique_date_sensor_pairs,
    SUM(group_rows - 1) AS duplicate_rows,
    SUM(
        CASE
            WHEN measurement_date IS NULL
              OR sensor_id IS NULL
            THEN group_rows
            ELSE 0
        END
    ) AS null_key_rows
FROM grouped;

SELECT COUNT(*) AS unmatched_air_quality_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily] AS aq
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
    ON aq.measurement_date = d.[date]
WHERE d.[date] IS NULL;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT [date]) AS unique_dates,
    COUNT(*) - COUNT(DISTINCT [date]) AS duplicate_or_null_dates,
    SUM(
        CASE WHEN [date] IS NULL THEN 1 ELSE 0 END
    ) AS null_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_date];

WITH grouped AS (
    SELECT
        trip_date,
        PULocationID,
        COUNT(*) AS group_rows
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date, PULocationID
)
SELECT
    SUM(group_rows) AS total_rows,
    COUNT(*) AS unique_date_zone_pairs,
    SUM(group_rows - 1) AS duplicate_rows,
    SUM(
        CASE
            WHEN trip_date IS NULL
              OR PULocationID IS NULL
            THEN group_rows
            ELSE 0
        END
    ) AS null_key_rows
FROM grouped;

SELECT COUNT(*) AS unmatched_taxi_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready] AS t
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
    ON t.trip_date = d.[date]
WHERE d.[date] IS NULL;

SELECT COUNT(*) AS unmatched_taxi_zones
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready] AS t
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_zone] AS z
    ON t.PULocationID = z.LocationID
WHERE z.LocationID IS NULL;

WITH grouped AS (
    SELECT
        pickup_date_ny,
        hour_ny,
        PULocationID,
        COUNT(*) AS group_rows
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly]
    GROUP BY pickup_date_ny, hour_ny, PULocationID
)
SELECT
    SUM(group_rows) AS total_rows,
    COUNT(*) AS unique_date_hour_zone,
    SUM(group_rows - 1) AS duplicate_rows,
    SUM(
        CASE
            WHEN pickup_date_ny IS NULL
              OR hour_ny IS NULL
              OR PULocationID IS NULL
            THEN group_rows
            ELSE 0
        END
    ) AS null_key_rows
FROM grouped;

SELECT
    (
        SELECT COUNT(*)
        FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
        LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
            ON t.pickup_date_ny = d.[date]
        WHERE d.[date] IS NULL
    ) AS unmatched_dates,

    (
        SELECT COUNT(*)
        FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
        LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_zone] AS z
            ON t.PULocationID = z.LocationID
        WHERE z.LocationID IS NULL
    ) AS unmatched_zones;


SELECT
    COUNT(*) AS total_stations,
    COUNT(DISTINCT station_id) AS unique_stations,
    COUNT(*) - COUNT(DISTINCT station_id) AS duplicate_or_null_ids,
    SUM(CASE WHEN station_id IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station];

SELECT
    COUNT(*) AS total_stations,
    SUM(
        CASE WHEN s.LocationID IS NULL THEN 1 ELSE 0 END
    ) AS stations_without_zone,
    SUM(
        CASE
            WHEN s.LocationID IS NOT NULL
             AND z.LocationID IS NULL
            THEN 1 ELSE 0
        END
    ) AS unmatched_zone_ids
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_zone] AS z
    ON s.LocationID = z.LocationID;


WITH grouped AS (
    SELECT
        station_id,
        measurement_date_ny,
        hour_ny,
        COUNT(*) AS group_rows
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly]
    GROUP BY
        station_id,
        measurement_date_ny,
        hour_ny
)
SELECT
    SUM(group_rows) AS total_rows,
    COUNT(*) AS unique_station_date_hour,
    SUM(group_rows - 1) AS duplicate_rows,
    SUM(
        CASE
            WHEN station_id IS NULL
              OR measurement_date_ny IS NULL
              OR hour_ny IS NULL
            THEN group_rows
            ELSE 0
        END
    ) AS null_key_rows
FROM grouped;


SELECT COUNT(*) AS unmatched_dates
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e
LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_date] AS d
    ON e.measurement_date_ny = d.[date]
WHERE d.[date] IS NULL;

SELECT
    COUNT(*) AS total_zones,
    COUNT(DISTINCT LocationID) AS unique_zones,
    COUNT(*) - COUNT(DISTINCT LocationID) AS duplicate_or_null_ids,
    SUM(
        CASE WHEN LocationID IS NULL THEN 1 ELSE 0 END
    ) AS null_ids
FROM [UrbanAnalyticsLH].[dbo].[gold_dim_zone];


WITH grouped AS (
    SELECT
        country,
        [year],
        COUNT(*) AS group_rows
    FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual]
    GROUP BY country, [year]
)
SELECT
    SUM(group_rows) AS total_rows,
    COUNT(*) AS unique_country_year_pairs,
    SUM(group_rows - 1) AS duplicate_rows,
    SUM(
        CASE
            WHEN country IS NULL
              OR [year] IS NULL
            THEN group_rows
            ELSE 0
        END
    ) AS null_key_rows
FROM grouped;