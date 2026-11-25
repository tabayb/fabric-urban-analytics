-- Q2: Taxi Demand vs Pollution Peaks
-- Which zones or times of day show the strongest
-- link between taxi demand and pollution peaks?
--
-- Data sources:
-- gold_fact_taxi_hourly
-- gold_fact_epa_no2_hourly
-- gold_dim_epa_station
-- gold_dim_zone
--
-- Period: June - July 2025

-- Q2: Step 1 - Check hourly data coverage

SELECT
    COUNT(*) AS total_epa_hours,
    SUM(
        CASE WHEN t.hourly_trips IS NOT NULL
        THEN 1 ELSE 0 END
    ) AS matched_hours,
    SUM(
        CASE WHEN t.hourly_trips IS NULL
        THEN 1 ELSE 0 END
    ) AS unmatched_hours
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
    ON e.station_id = s.station_id

LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
    ON s.LocationID = t.PULocationID
    AND e.measurement_date_ny = t.pickup_date_ny
    AND e.hour_ny = t.hour_ny;


-- Q2: Step 2 - Hourly coverage by EPA station and Taxi Zone

SELECT
    e.station_id,
    s.LocationID,
    COUNT(*) AS total_epa_hours,
    COUNT(t.hourly_trips) AS matched_hours,
    ROUND(
        100.0 * COUNT(t.hourly_trips) / NULLIF(COUNT(*), 0),
        2
    ) AS match_percentage
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
    ON e.station_id = s.station_id

LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
    ON s.LocationID = t.PULocationID
    AND e.measurement_date_ny = t.pickup_date_ny
    AND e.hour_ny = t.hour_ny

GROUP BY
    e.station_id,
    s.LocationID

ORDER BY match_percentage DESC;

-- Q2: Step 3 - Pearson correlation by Taxi Zone

;WITH paired AS (
    SELECT
        e.station_id,
        s.LocationID,
        CAST(t.hourly_trips AS FLOAT) AS trips,
        CAST(e.avg_no2_ppb AS FLOAT) AS no2
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
        ON e.station_id = s.station_id
    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
        ON s.LocationID = t.PULocationID
        AND e.measurement_date_ny = t.pickup_date_ny
        AND e.hour_ny = t.hour_ny
    WHERE e.avg_no2_ppb IS NOT NULL
),
stats AS (
    SELECT
        station_id,
        LocationID,
        COUNT(*) AS matched_hours,
        AVG(trips) AS mean_trips,
        AVG(no2) AS mean_no2,
        AVG(trips * no2) AS mean_xy,
        STDEVP(trips) AS sd_trips,
        STDEVP(no2) AS sd_no2
    FROM paired
    GROUP BY station_id, LocationID
)
SELECT
    station_id,
    LocationID,
    matched_hours,
    ROUND(
        (mean_xy - mean_trips * mean_no2)
        / NULLIF(sd_trips * sd_no2, 0),
        3
    ) AS pearson_r
FROM stats
ORDER BY pearson_r DESC;

-- Q2: Step 4 - Matched observations by hour of day

SELECT
    e.hour_ny,
    COUNT(*) AS matched_observations,
    COUNT(DISTINCT e.measurement_date_ny) AS days_with_matches,
    COUNT(DISTINCT e.station_id) AS stations_with_matches
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
    ON e.station_id = s.station_id

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
    ON s.LocationID = t.PULocationID
    AND e.measurement_date_ny = t.pickup_date_ny
    AND e.hour_ny = t.hour_ny

GROUP BY e.hour_ny
ORDER BY e.hour_ny;


-- Q2: Step 5 - Pearson correlation by hour of day

;WITH paired AS (
    SELECT
        e.hour_ny,
        CAST(t.hourly_trips AS FLOAT) AS trips,
        CAST(e.avg_no2_ppb AS FLOAT) AS no2
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e

    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
        ON e.station_id = s.station_id

    INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
        ON s.LocationID = t.PULocationID
        AND e.measurement_date_ny = t.pickup_date_ny
        AND e.hour_ny = t.hour_ny

    WHERE e.avg_no2_ppb IS NOT NULL
),
stats AS (
    SELECT
        hour_ny,
        COUNT(*) AS matched_hours,
        AVG(trips) AS mean_trips,
        AVG(no2) AS mean_no2,
        AVG(trips * no2) AS mean_xy,
        STDEVP(trips) AS sd_trips,
        STDEVP(no2) AS sd_no2
    FROM paired
    GROUP BY hour_ny
)
SELECT
    hour_ny,
    matched_hours,
    ROUND(
        (mean_xy - mean_trips * mean_no2)
        / NULLIF(sd_trips * sd_no2, 0),
        3
    ) AS pearson_r
FROM stats
ORDER BY hour_ny;


-- Q2: Step 6 - Average NO2 and taxi activity by hour

SELECT TOP (10)
    e.hour_ny,
    COUNT(*) AS matched_observations,
    ROUND(AVG(CAST(e.avg_no2_ppb AS FLOAT)), 2) AS avg_no2_ppb,
    ROUND(AVG(CAST(t.hourly_trips AS FLOAT)), 2) AS avg_hourly_trips

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_epa_no2_hourly] AS e

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_dim_epa_station] AS s
    ON e.station_id = s.station_id

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly] AS t
    ON s.LocationID = t.PULocationID
    AND e.measurement_date_ny = t.pickup_date_ny
    AND e.hour_ny = t.hour_ny

WHERE e.avg_no2_ppb IS NOT NULL

GROUP BY e.hour_ny
ORDER BY avg_no2_ppb DESC;

-- Q2 FINAL RESULTS
-- Period: June - July 2025
-- EPA hourly observations: 4811
-- Matched Taxi/EPA observations: 1841 (38.3%)
--
-- Highest positive zone correlation:
-- Kew Gardens Hills (LocationID 135), r = 0.175
--
-- Highest positive hourly correlation:
-- 04:00, r = 0.250
--
-- Peak average NO2 (matched observations):
-- 05:00, 16.00 ppb
--
-- Conclusion:
-- The observed correlations are weak.
-- Findings are limited to four EPA monitoring zones
-- and hours with matching taxi records.
-- Correlation does not imply causation.