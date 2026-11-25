-- Q1: Traffic Intensity vs Air Quality
-- Step 1: Check overlapping dates

SELECT COUNT(*) AS common_dates
FROM (
    SELECT DISTINCT trip_date
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
) AS t
INNER JOIN (
    SELECT DISTINCT measurement_date
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]
) AS aq
    ON t.trip_date = aq.measurement_date;


-- Q1: Step 2 - Calculate total taxi trips per day

SELECT TOP (10)
    trip_date,
    SUM(daily_trips) AS total_daily_trips
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
GROUP BY trip_date
ORDER BY trip_date;

-- Q1: Step 3 - Examine daily PM2.5 measurements

SELECT TOP (10)
    measurement_date,
    sensor_id,
    avg_pm25,
    measurement_count
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]
ORDER BY measurement_date;

-- Q1: Step 4 - Join daily taxi traffic with PM2.5

WITH taxi_daily AS (
    SELECT
        trip_date,
        SUM(daily_trips) AS total_daily_trips
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date
)

SELECT TOP (10)
    t.trip_date,
    t.total_daily_trips,
    aq.avg_pm25,
    aq.measurement_count
FROM taxi_daily AS t
INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily] AS aq
    ON t.trip_date = aq.measurement_date
ORDER BY t.trip_date;

-- Q1: Step 5 - Pearson correlation (Taxi vs PM2.5)

WITH taxi_daily AS (
    SELECT
        trip_date,
        SUM(daily_trips) AS total_daily_trips
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date
),
paired AS (
    SELECT
        CAST(t.total_daily_trips AS FLOAT) AS trips,
        CAST(aq.avg_pm25 AS FLOAT) AS pm25
    FROM taxi_daily AS t
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily] AS aq
        ON t.trip_date = aq.measurement_date
    WHERE aq.avg_pm25 IS NOT NULL
),
stats AS (
    SELECT
        COUNT(*) AS days_compared,
        AVG(trips) AS mean_trips,
        AVG(pm25) AS mean_pm25,
        AVG(trips * pm25) AS mean_xy,
        STDEVP(trips) AS sd_trips,
        STDEVP(pm25) AS sd_pm25
    FROM paired
)
SELECT
    days_compared,
    ROUND(
        (mean_xy - mean_trips * mean_pm25)
        / NULLIF(sd_trips * sd_pm25, 0),
        3
    ) AS pearson_r
FROM stats;

-- Q1: Step 6 - Examine daily NO2 measurements

SELECT TOP (10)
    measurement_date,
    avg_no2_ppm,
    max_no2_ppm,
    measurement_count
FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily]
ORDER BY measurement_date;


-- Q1: Step 7 - Pearson correlation (Taxi vs NO2)

WITH taxi_daily AS (
    SELECT
        trip_date,
        SUM(daily_trips) AS total_daily_trips
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date
),
paired AS (
    SELECT
        CAST(t.total_daily_trips AS FLOAT) AS trips,
        CAST(n.avg_no2_ppm AS FLOAT) AS no2
    FROM taxi_daily AS t
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_no2_daily] AS n
        ON t.trip_date = n.measurement_date
    WHERE n.avg_no2_ppm IS NOT NULL
),
stats AS (
    SELECT
        COUNT(*) AS days_compared,
        AVG(trips) AS mean_trips,
        AVG(no2) AS mean_no2,
        AVG(trips * no2) AS mean_xy,
        STDEVP(trips) AS sd_trips,
        STDEVP(no2) AS sd_no2
    FROM paired
)
SELECT
    days_compared,
    ROUND(
        (mean_xy - mean_trips * mean_no2)
        / NULLIF(sd_trips * sd_no2, 0),
        3
    ) AS pearson_r
FROM stats;


-- Q1: Cross-check both Pearson correlations

WITH taxi_daily AS (
    SELECT
        trip_date,
        SUM(daily_trips) AS total_daily_trips
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date
),
paired AS (
    SELECT
        CAST(t.total_daily_trips AS FLOAT) AS trips,
        CAST(a.avg_pm25 AS FLOAT) AS pm25,
        CAST(n.avg_no2_ppm AS FLOAT) AS no2
    FROM taxi_daily AS t
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily] AS a
        ON t.trip_date = a.measurement_date
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_no2_daily] AS n
        ON t.trip_date = n.measurement_date
    WHERE a.avg_pm25 IS NOT NULL
      AND n.avg_no2_ppm IS NOT NULL
),
stats AS (
    SELECT
        COUNT(*) AS days_compared,
        AVG(trips) AS mean_trips,
        AVG(pm25) AS mean_pm25,
        AVG(no2) AS mean_no2,
        AVG(trips * pm25) AS mean_trips_pm25,
        AVG(trips * no2) AS mean_trips_no2,
        STDEVP(trips) AS sd_trips,
        STDEVP(pm25) AS sd_pm25,
        STDEVP(no2) AS sd_no2
    FROM paired
)
SELECT
    days_compared,
    ROUND(
        (mean_trips_pm25 - mean_trips * mean_pm25)
        / NULLIF(sd_trips * sd_pm25, 0), 6
    ) AS correlation_pm25,
    ROUND(
        (mean_trips_no2 - mean_trips * mean_no2)
        / NULLIF(sd_trips * sd_no2, 0), 6
    ) AS correlation_no2
FROM stats;


-- Q1 FINAL RESULTS
-- Period: June 1 - July 31, 2025
-- Days compared: 61
-- Taxi vs PM2.5: r = 0.177881 (weak positive)
-- Taxi vs NO2:   r = 0.396129 (moderate positive)
-- Conclusion: NO2 has a stronger positive linear
-- association with daily taxi trips than PM2.5.
-- Limitation: Correlation does not imply causation.