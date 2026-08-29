{{
  config(
    materialized = 'table'
  )
}}

WITH date_spine AS (
  SELECT CAST(RANGE AS DATE) AS date_id
  FROM RANGE(
    DATE '2008-01-01',
    DATE '2028-01-01',
    INTERVAL '1 DAY'
  )
),

full_moon_dates AS (
  SELECT full_moon_date FROM {{ ref('seed_full_moon_dates') }}
),

final AS (
  SELECT
    d.date_id,
    YEAR(d.date_id)                                           AS year,
    QUARTER(d.date_id)                                        AS quarter,
    MONTH(d.date_id)                                          AS month,
    STRFTIME(d.date_id, '%B')                                 AS month_name,
    WEEKOFYEAR(d.date_id)                                     AS week_of_year,
    DAY(d.date_id)                                            AS day_of_month,
    DAYOFWEEK(d.date_id)                                      AS day_of_week,
    STRFTIME(d.date_id, '%A')                                 AS weekday_name,
    CASE WHEN DAYOFWEEK(d.date_id) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE
      WHEN MONTH(d.date_id) IN (12, 1, 2)  THEN 'Winter'
      WHEN MONTH(d.date_id) IN (3, 4, 5)   THEN 'Spring'
      WHEN MONTH(d.date_id) IN (6, 7, 8)   THEN 'Summer'
      WHEN MONTH(d.date_id) IN (9, 10, 11) THEN 'Autumn'
    END                                                        AS season,
    CASE WHEN fm.full_moon_date IS NOT NULL THEN TRUE ELSE FALSE END AS is_full_moon
  FROM date_spine d
  LEFT JOIN full_moon_dates fm
    ON d.date_id = fm.full_moon_date
)

SELECT * FROM final
