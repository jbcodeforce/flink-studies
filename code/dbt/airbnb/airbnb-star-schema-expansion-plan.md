# Airbnb dbt Star Schema Expansion Plan

## Overview

Expand the existing single-fact star schema (currently only `fct_reviews`) into a
multi-fact star schema that covers the core Airbnb analytical domains:
**pricing**, **listings activity**, **review quality**, and **host performance**.

All new models use **full-refresh** materialization (no incremental logic).  
A new `dim_date` calendar dimension is added and shared across all fact tables.

---

## Current State

| Layer | Existing Models |
|-------|----------------|
| Staging | `src_reviews`, `src_listings`, `src_hosts` |
| Dimensions | `dim_listings_cleansed`, `dim_hosts_cleansed`, `dim_listings_with_hosts` |
| Facts | `fct_reviews` (incremental) |
| Seeds | `seed_full_moon_dates` |

**Grain of `fct_reviews`:** one row per review event.  
**Available source columns:** See staging layer summary below.

---

## Sub-Tasks

---

### Sub-Task 1 — Add `dim_date` Calendar Dimension

**Intent:**  
Create a shared date dimension that all fact tables can join to. Enriches any
`DATE`/`TIMESTAMP` key with human-readable attributes used in slicing and grouping.

**Expected Outcomes:**
- `dim_date` table exists in `models/dimensions/`
- Covers every calendar date that appears across `review_date`, `created_at` in listings and hosts
- Columns: `date_id` (DATE PK), `year`, `quarter`, `month`, `month_name`, `week_of_year`, `day_of_month`, `day_of_week`, `weekday_name`, `is_weekend`, `season`, `is_full_moon`
- `is_full_moon` joins to `seed_full_moon_dates` via a LEFT JOIN

**Todo List:**
1. Create `models/dimensions/dim_date.sql`
   - Generate date spine using a CTE or `generate_series` (DuckDB compatible)
   - Date range: 2008-01-01 through 2027-12-31 (covers all source data + forecast)
   - Derive `year`, `quarter`, `month`, `month_name`, `week_of_year`, `day_of_month`, `day_of_week`, `weekday_name`, `is_weekend`
   - Derive `season` via CASE on month (Dec–Feb = Winter, Mar–May = Spring, etc.)
   - LEFT JOIN to `{{ ref('seed_full_moon_dates') }}` and flag `is_full_moon`
2. Add `dim_date` entry to `models/schema.yaml` with `not_null` + `unique` on `date_id`
3. Set materialization to `table` in `dbt_project.yml` under `dimensions/`

**Relevant Context:**
- [`macros/date_utils.sql`](models/../macros/date_utils.sql) — portable `to_date()` macro
- [`seeds/seed_full_moon_dates.csv`](seeds/seed_full_moon_dates.csv) — 273 dates 2009–2026
- DuckDB supports `GENERATE_SERIES` and `INTERVAL` arithmetic natively

**Status:** [x] done

---

### Sub-Task 2 — Add `fct_listing_pricing` Fact Table

**Intent:**  
Capture the pricing state of every listing as a slowly-materializing snapshot fact.
Enables price distribution, pricing tier analysis, and price vs. review-score correlation.

**Expected Outcomes:**
- `fct_listing_pricing` table in `models/facts/`
- One row per listing (latest state)
- Columns: `listing_id`, `snapshot_date`, `price`, `minimum_nights`, `room_type`, `host_id`, `price_tier` (derived bucket), `min_stay_bucket` (derived)

**Todo List:**
1. Create `models/facts/fct_listing_pricing.sql`
   - Source: `{{ ref('dim_listings_cleansed') }}`
   - Derive `price_tier` via CASE:
     - Budget: price < 50
     - Mid-range: 50–149
     - Premium: 150–299
     - Luxury: >= 300
   - Derive `min_stay_bucket`:
     - Short (1–3 nights), Medium (4–14), Long (15–30), Extended (> 30)
   - Add `snapshot_date` as `CURRENT_DATE` (or `updated_at` cast to DATE)
2. Add `fct_listing_pricing` to `models/schema.yaml` with FK relationships to `dim_listings_cleansed`
3. Add `not_null` test on `listing_id` and `price`

**Relevant Context:**
- [`models/dimensions/dim_listings_cleansed.sql`](models/dimensions/dim_listings_cleansed.sql) — `price` already cast to DECIMAL(10,2)
- [`models/src/src_listings.sql`](models/src/src_listings.sql) — original `price_str` stripped of `$`

**Status:** [x] done

---

### Sub-Task 3 — Add `fct_review_summary` Fact Table

**Intent:**  
Aggregate reviews to listing-month grain so analysts can track review volume,
sentiment trends, and full-moon correlation over time without scanning the raw
`fct_reviews` event table.

**Expected Outcomes:**
- `fct_review_summary` table in `models/facts/`
- Grain: one row per `(listing_id, review_month)` — i.e. YEAR + MONTH of `review_date`
- Columns: `listing_id`, `review_month` (DATE truncated to month), `total_reviews`, `positive_reviews`, `neutral_reviews`, `negative_reviews`, `positive_pct`, `full_moon_reviews`
- `full_moon_reviews` = count of reviews that fall on a full-moon date

**Todo List:**
1. Create `models/facts/fct_review_summary.sql`
   - Source: `{{ ref('fct_reviews') }}`
   - LEFT JOIN to `{{ ref('seed_full_moon_dates') }}` on `review_date::DATE = full_moon_date`
   - GROUP BY `listing_id`, `DATE_TRUNC('month', review_date)::DATE`
   - Compute: `COUNT(*)`, `SUM(CASE WHEN sentiment='positive')`, `SUM(CASE neutral)`, `SUM(CASE negative)`, `ROUND(positive / total * 100, 1)`, `SUM(CASE full_moon)`
2. Add to `models/schema.yaml` with FK test on `listing_id` → `dim_listings_cleansed`

**Relevant Context:**
- [`models/facts/fct_reviews.sql`](models/facts/fct_reviews.sql) — source event table with `listing_id`, `review_date`, `review_sentiment`
- [`seeds/seed_full_moon_dates.csv`](seeds/seed_full_moon_dates.csv) — join key: `full_moon_date`
- DuckDB `DATE_TRUNC('month', expr)` supported natively

**Status:** [x] done

---

### Sub-Task 4 — Add `fct_host_performance` Fact Table

**Intent:**  
Aggregate listing and review data at host-month grain to produce a host
performance scorecard: portfolio size, total reviews, sentiment score, and
revenue proxy. Directly feeds host-tier dashboards and superhost analysis.

**Expected Outcomes:**
- `fct_host_performance` table in `models/facts/`
- Grain: one row per `(host_id, review_month)`
- Columns: `host_id`, `review_month`, `active_listings`, `total_reviews`, `positive_reviews`, `negative_reviews`, `sentiment_score` (positive_pct), `avg_price`, `estimated_monthly_revenue` (total_reviews × avg_price as proxy), `is_superhost`

**Todo List:**
1. Create `models/facts/fct_host_performance.sql`
   - Join `fct_reviews` → `dim_listings_cleansed` on `listing_id`
   - Join to `dim_hosts_cleansed` on `host_id`
   - GROUP BY `host_id`, `is_superhost`, `DATE_TRUNC('month', review_date)`
   - Compute: `COUNT(DISTINCT listing_id)`, review counts by sentiment, `AVG(price)`, `estimated_monthly_revenue = COUNT(*) * AVG(price)`
   - Add `sentiment_score = ROUND(positive / total * 100, 1)`
2. Add to `models/schema.yaml` with FK test on `host_id` → `dim_hosts_cleansed`

**Relevant Context:**
- [`models/dimensions/dim_listings_with_hosts.sql`](models/dimensions/dim_listings_with_hosts.sql) — already joins listings + hosts; can use as shortcut source
- [`models/facts/fct_reviews.sql`](models/facts/fct_reviews.sql) — supplies review events with `listing_id`

**Status:** [x] done

---

### Sub-Task 5 — Add `fct_listing_activity` Fact Table

**Intent:**  
Track listing-level engagement over time: when a listing was active (had reviews),
its review velocity, and its review recency. Supports "listing churn" and
"dormant listing" analyses.

**Expected Outcomes:**
- `fct_listing_activity` table in `models/facts/`
- Grain: one row per listing (current snapshot)
- Columns: `listing_id`, `host_id`, `room_type`, `price`, `first_review_date`, `last_review_date`, `days_active` (last − first), `total_reviews`, `avg_days_between_reviews`, `days_since_last_review`, `activity_status` (Active / Dormant / New)

**Todo List:**
1. Create `models/facts/fct_listing_activity.sql`
   - Source: aggregate `fct_reviews` GROUP BY `listing_id`
   - Join to `dim_listings_cleansed` for `host_id`, `room_type`, `price`
   - Compute `first_review_date = MIN(review_date)`, `last_review_date = MAX(review_date)`
   - `days_active = DATEDIFF('day', first_review_date, last_review_date)`
   - `avg_days_between_reviews = days_active / NULLIF(total_reviews - 1, 0)`
   - `days_since_last_review = DATEDIFF('day', last_review_date, CURRENT_DATE)`
   - `activity_status` CASE:
     - 'New' if total_reviews <= 3
     - 'Active' if days_since_last_review <= 180
     - 'Dormant' otherwise
2. Add to `models/schema.yaml` with not_null + unique on `listing_id`, FK to `dim_listings_cleansed`

**Relevant Context:**
- [`models/facts/fct_reviews.sql`](models/facts/fct_reviews.sql) — source event grain
- [`models/dimensions/dim_listings_cleansed.sql`](models/dimensions/dim_listings_cleansed.sql) — listing attributes

**Status:** [x] done

---

### Sub-Task 6 — Update `schema.yaml` and `dbt_project.yml`

**Intent:**  
Ensure all new models are registered with data tests and materialization settings,
so `dbt test` and `dbt run` work cleanly with no warnings.

**Expected Outcomes:**
- All 4 new fact tables and `dim_date` have entries in `models/schema.yaml`
- All FK relationships are declared
- `dbt_project.yml` sets `facts/` to `table` materialization
- `dbt run && dbt test` passes with zero failures

**Todo List:**
1. Add schema entries in `models/schema.yaml` for:
   - `dim_date` — not_null + unique on `date_id`
   - `fct_listing_pricing` — not_null on `listing_id`, `price`; FK to `dim_listings_cleansed`
   - `fct_review_summary` — not_null on `listing_id`; FK to `dim_listings_cleansed`
   - `fct_host_performance` — not_null on `host_id`; FK to `dim_hosts_cleansed`
   - `fct_listing_activity` — not_null + unique on `listing_id`; FK to `dim_listings_cleansed`
2. In `dbt_project.yml` under `models > airbnb > facts`, set `+materialized: table`
3. Run `dbt run --select facts+ dimensions+` to validate
4. Run `dbt test` to confirm all tests pass

**Relevant Context:**
- [`dbt_project.yml`](dbt_project.yml) — existing materialization overrides
- [`models/schema.yaml`](models/schema.yaml) — existing test patterns to follow

**Status:** [x] done

---

## Resulting Star Schema

```
                    dim_date
                       |
        +--------------+--------------+
        |              |              |
fct_listing_pricing  fct_review_summary  fct_host_performance
        |              |              |
        +------+--------+------+------+
               |               |
        dim_listings_cleansed  dim_hosts_cleansed
               |               |
        dim_listings_with_hosts (denormalized BI layer)
               |
       fct_listing_activity
```

---

## New Fact Table Analytical Use Cases

| Fact Table | Key Questions Answered |
|---|---|
| `fct_listing_pricing` | What is the price distribution by room type? Which listings are luxury vs budget? |
| `fct_review_summary` | Which listings have the highest positive-sentiment rate by month? Do full moons affect review sentiment? |
| `fct_host_performance` | Who are the top-performing hosts? Does superhost status correlate with sentiment score? |
| `fct_listing_activity` | Which listings are dormant? What is the review velocity per listing? |
| `dim_date` | Slice all facts by weekday, season, quarter, full-moon phase |
