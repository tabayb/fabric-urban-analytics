-- Q4: Step 1 - Check GDP Historical Coverage

SELECT
    country,
    MIN(year) AS first_year,
    MAX(year) AS last_year,
    COUNT(*) AS years_available
FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual]
GROUP BY country
ORDER BY country;

-- Q4: Step 2 - USA GDP Year-over-Year Growth

;WITH gdp_trend AS (
    SELECT
        country,
        year,
        gdp_usd,

        LAG(gdp_usd) OVER (
            PARTITION BY country
            ORDER BY year
        ) AS previous_year_gdp

    FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual]
    WHERE country = 'USA'
)

SELECT
    year,
    gdp_usd,
    previous_year_gdp,

    CAST(
        100.0 * (gdp_usd - previous_year_gdp)
        / NULLIF(previous_year_gdp, 0)
        AS DECIMAL(10,2)
    ) AS gdp_growth_pct

FROM gdp_trend

WHERE year BETWEEN 2020 AND 2025
ORDER BY year;


-- Q4: Step 3 - Verify Mobility and Air Quality Coverage

SELECT
    'NYC Taxi' AS dataset,
    MIN(trip_date) AS first_date,
    MAX(trip_date) AS last_date,
    COUNT(DISTINCT trip_date) AS days_available
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]

UNION ALL

SELECT
    'PM2.5',
    MIN(measurement_date),
    MAX(measurement_date),
    COUNT(DISTINCT measurement_date)
FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]

UNION ALL

SELECT
    'NO2',
    MIN(measurement_date),
    MAX(measurement_date),
    COUNT(DISTINCT measurement_date)
FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily];


-- Q4 FINAL RESULTS
-- GDP coverage: 1960-2025 (USA and Germany)
-- Taxi coverage: June-July 2025 (61 days)
-- PM2.5 coverage: June-July 2025 (61 days)
-- NO2 coverage: June-July 2025 (61 days)
--
-- Conclusion:
-- Long-term cross-domain trends cannot be established
-- due to insufficient historical mobility and air quality data.