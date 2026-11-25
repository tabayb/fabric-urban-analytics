-- ===========================================================
-- Microsoft Fabric Urban Analytics
-- Warehouse Full Refresh
--
-- Target: UrbanAnalyticsWH
-- Source: UrbanAnalyticsLH
-- Period: June - July 2025
--
-- Refresh: 8 Warehouse tables
-- EPA tables remain untouched
-- ============================================================
-- ============================================================
-- STEP 1: PRE-FLIGHT DATA QUALITY CHECKS
-- ============================================================
-- DimDate: minimum 61 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_dim_date]
) < 61
    THROW 51001, 'Refresh cancelled: incomplete DimDate.', 1;
-- DimZone: minimum 265 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_dim_zone]
) < 265
    THROW 51002, 'Refresh cancelled: incomplete DimZone.', 1;
-- DimFX: minimum 61 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily]
) < 61
    THROW 51003, 'Refresh cancelled: incomplete DimFX.', 1;
-- DimGDP: minimum 132 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual]
) < 132
    THROW 51004, 'Refresh cancelled: incomplete DimGDP.', 1;
-- FactTaxiDaily: minimum 14932 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready]
) < 14932
    THROW 51005, 'Refresh cancelled: incomplete FactTaxiDaily.', 1;
-- FactAirQualityDaily: minimum 61 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily]
) < 61
    THROW 51006, 'Refresh cancelled: incomplete FactAirQualityDaily.', 1;
-- FactTaxiHourly: minimum 2334 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly]
) < 2334
    THROW 51007, 'Refresh cancelled: incomplete FactTaxiHourly.', 1;
-- FactNO2Daily: minimum 61 rows
IF (
    SELECT COUNT_BIG(*)
    FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily]
) < 61
    THROW 51008, 'Refresh cancelled: incomplete FactNO2Daily.', 1;
-- ============================================================
-- STEP 2: TRANSACTIONAL WAREHOUSE REFRESH
-- ============================================================
BEGIN TRY
    BEGIN TRAN;
    -- --------------------------------------------------------
    -- 1. DimDate
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.DimDate;
    INSERT INTO dbo.DimDate (
        [date],
        DateKey,
        [Year],
        [Month],
        [Quarter],
        DayOfWeek,
        IsWeekend,
        MonthName,
        DayName
    )
    SELECT
        [date],
        DateKey,
        [Year],
        [Month],
        [Quarter],
        DayOfWeek,
        IsWeekend,
        MonthName,
        DayName
    FROM [UrbanAnalyticsLH].[dbo].[gold_dim_date];
    -- --------------------------------------------------------
    -- 2. DimZone
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.DimZone;
    INSERT INTO dbo.DimZone (
        LocationID,
        Borough,
        [Zone],
        service_zone
    )
    SELECT
        LocationID,
        Borough,
        [Zone],
        service_zone
    FROM [UrbanAnalyticsLH].[dbo].[gold_dim_zone];
    -- --------------------------------------------------------
    -- 3. DimFX
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.DimFX;
    INSERT INTO dbo.DimFX (
        rate_date,
        usd_per_eur
    )
    SELECT
        rate_date,
        usd_per_eur
    FROM [UrbanAnalyticsLH].[dbo].[gold_fx_daily];
    -- --------------------------------------------------------
    -- 4. DimGDP
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.DimGDP;
    INSERT INTO dbo.DimGDP (
        country,
        [year],
        gdp_usd
    )
    SELECT
        country,
        [year],
        gdp_usd
    FROM [UrbanAnalyticsLH].[dbo].[gold_gdp_annual];
    -- --------------------------------------------------------
    -- 5. FactTaxiDaily
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.FactTaxiDaily;
    INSERT INTO dbo.FactTaxiDaily (
        trip_date,
        PULocationID,
        daily_trips,
        total_amount_usd,
        avg_fare_usd,
        avg_duration_minutes,
        positive_charged_amount_usd,
        total_amount_eur,
        positive_charged_amount_eur
    )
    SELECT
        trip_date,
        PULocationID,
        daily_trips,
        total_amount_usd,
        avg_fare_usd,
        avg_duration_minutes,
        positive_charged_amount_usd,
        total_amount_eur,
        positive_charged_amount_eur
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_daily_ready];
    -- --------------------------------------------------------
    -- 6. FactAirQualityDaily
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.FactAirQualityDaily;
    INSERT INTO dbo.FactAirQualityDaily (
        measurement_date,
        sensor_id,
        avg_pm25,
        measurement_count
    )
    SELECT
        measurement_date,
        sensor_id,
        avg_pm25,
        measurement_count
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_air_quality_daily];
    -- --------------------------------------------------------
    -- 7. FactTaxiHourly
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.FactTaxiHourly;
    INSERT INTO dbo.FactTaxiHourly (
        PULocationID,
        pickup_date_ny,
        hour_ny,
        hourly_trips
    )
    SELECT
        PULocationID,
        pickup_date_ny,
        hour_ny,
        hourly_trips
    FROM [UrbanAnalyticsLH].[dbo].[gold_fact_taxi_hourly];
    -- --------------------------------------------------------
    -- 8. FactNO2Daily
    -- --------------------------------------------------------
    TRUNCATE TABLE dbo.FactNO2Daily;
    INSERT INTO dbo.FactNO2Daily (
        measurement_date,
        avg_no2_ppm,
        max_no2_ppm,
        measurement_count
    )
    SELECT
        measurement_date,
        avg_no2_ppm,
        max_no2_ppm,
        measurement_count
    FROM [UrbanAnalyticsLH].[dbo].[gold_no2_daily];
    -- --------------------------------------------------------
    -- COMMIT ALL CHANGES
    -- --------------------------------------------------------
    COMMIT TRAN;
END TRY
BEGIN CATCH
    -- Roll back if any statement fails
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;
    -- Return the error to Fabric Pipeline
    THROW;
END CATCH;