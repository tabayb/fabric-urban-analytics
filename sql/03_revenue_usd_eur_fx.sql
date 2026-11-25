-- Q3: Step 1 - Explore Taxi Revenue and FX Rates

SELECT TOP (5)
    t.trip_date,
    SUM(t.daily_trips) AS total_trips,
    SUM(t.total_amount_usd) AS revenue_usd,
    SUM(t.total_amount_eur) AS revenue_eur,
    MAX(f.usd_per_eur) AS usd_per_eur

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready] AS t

LEFT JOIN [UrbanAnalyticsLH].[dbo].[gold_fx_daily] AS f
    ON t.trip_date = f.rate_date

-- Q3: Step 2 - Average Revenue per Trip in USD and EUR

SELECT TOP (5)
    trip_date,
    SUM(daily_trips) AS total_trips,

    CAST(
        SUM(total_amount_usd) /
        NULLIF(SUM(daily_trips), 0)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_trip_usd,

    CAST(
        SUM(total_amount_eur) /
        NULLIF(SUM(daily_trips), 0)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_trip_eur

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]

GROUP BY trip_date
ORDER BY trip_date;

-- Q3: Step 3 - Exchange Rate Fluctuation

SELECT
    COUNT(*) AS total_days,
    MIN(usd_per_eur) AS min_fx_rate,
    MAX(usd_per_eur) AS max_fx_rate,
    ROUND(AVG(usd_per_eur), 4) AS avg_fx_rate
FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily]
WHERE rate_date BETWEEN '2025-06-01' AND '2025-07-31';

-- Q3: Step 4 - FX Impact on a Fixed USD Fare

-- Q3: Step 5 - Actual Revenue vs Fixed FX Rate

SELECT TOP (5)
    t.trip_date,

    SUM(t.total_amount_usd) AS revenue_usd,

    MAX(f.usd_per_eur) AS actual_fx_rate,

    SUM(t.total_amount_eur) AS actual_revenue_eur,

    CAST(
        SUM(t.total_amount_usd) / 1.1339
        AS DECIMAL(18,2)
    ) AS revenue_eur_fixed_fx

FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready] AS t

INNER JOIN [UrbanAnalyticsLH].[dbo].[gold_fx_daily] AS f
    ON t.trip_date = f.rate_date

GROUP BY t.trip_date
ORDER BY t.trip_date;

-- Q3: Step 6 - FX Impact in EUR and Percentage

;WITH daily_revenue AS (
    SELECT
        trip_date,
        SUM(total_amount_usd) AS revenue_usd,
        SUM(total_amount_eur) AS actual_eur,
        SUM(total_amount_usd) / 1.1339 AS fixed_eur
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
    GROUP BY trip_date
)

SELECT TOP (5)
    trip_date,

    CAST(actual_eur - fixed_eur AS DECIMAL(18,2))
        AS fx_impact_eur,

    CAST(
        100.0 * (actual_eur - fixed_eur)
        / NULLIF(fixed_eur, 0)
        AS DECIMAL(10,2)
    ) AS fx_impact_pct

FROM daily_revenue
ORDER BY trip_date;

-- Q3: Step 7 - Final Results for June-July 2025

;WITH totals AS (
    SELECT
        COUNT(DISTINCT trip_date) AS days_analyzed,
        SUM(daily_trips) AS total_trips,
        SUM(total_amount_usd) AS revenue_usd,
        SUM(total_amount_eur) AS revenue_eur
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
)
SELECT
    days_analyzed,
    total_trips,

    CAST(
        revenue_usd / NULLIF(total_trips, 0)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_trip_usd,

    CAST(
        revenue_eur / NULLIF(total_trips, 0)
        AS DECIMAL(18,2)
    ) AS avg_revenue_per_trip_eur,

    CAST(revenue_usd AS DECIMAL(18,2))
        AS total_revenue_usd,

    CAST(revenue_eur AS DECIMAL(18,2))
        AS actual_revenue_eur,

    CAST(
        revenue_eur - (revenue_usd / 1.1339)
        AS DECIMAL(18,2)
    ) AS total_fx_impact_eur,

    CAST(
        100.0 * (revenue_eur - revenue_usd / 1.1339)
        / NULLIF(revenue_usd / 1.1339, 0)
        AS DECIMAL(10,2)
    ) AS total_fx_impact_pct

FROM totals;


-- Q3 FINAL RESULTS
-- Period: June - July 2025
-- Days analyzed: 61
-- Total trips: 8097203
-- Average revenue per trip USD: 27.14
-- Average revenue per trip EUR: 23.42
-- Total revenue USD: 219764965.42
-- Actual revenue EUR: 189630019.62
-- FX impact EUR: -4183337.31
-- FX impact percentage: -2.16%
--
-- Conclusion:
-- Exchange rate fluctuations reduced the EUR
-- equivalent by 2.16% relative to a fixed FX
-- rate of 1.1339.
-- This is a conversion effect, not a realized loss.