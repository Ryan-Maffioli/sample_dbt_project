-- #3 - Picky Renter Longest Stay:
-- Write a query to calculate the longest continuous stay available for properties that have both a lockbox and a first aid kit.
-- Tip: Stay duration cannot exceed the host's maximum_nights limit.

{{
    config(
        materialized = "table"
    )
}}

--#1: We are going to start by bringing in the core daily fact table containing point-in-time amenity flags.
WITH 
    fct_daily_listing_performance AS (SELECT * FROM {{ ref('fct_daily_listing_performance') }}),
    
--#2: Isolate dates on which the listing satisfies all requirements.
-- has_lockbox / has_first_aid_kit = TRUE also drops unknown (NULL) amenity flags.
qualified_available_days AS (
    SELECT
        listing_id,
        date,
        minimum_nights,
        maximum_nights
    FROM fct_daily_listing_performance
    WHERE is_available = TRUE
      AND has_lockbox = TRUE
      AND has_first_aid_kit = TRUE
),

--#3: Gaps and Islands:
-- Consecutive dates will share the same island_group.
consecutive_islands AS (
    SELECT
        listing_id,
        date,
        minimum_nights,
        maximum_nights,
        DATE_SUB(
            date,
            INTERVAL ROW_NUMBER() OVER (
                PARTITION BY listing_id
                ORDER BY date
            ) DAY
        ) AS island_group
    FROM qualified_available_days
),

--#4: From each possible start date, remaining_nights is nights left in that island
-- (not the full island length). That is what a stay starting on this date can actually use.
remaining AS (
    SELECT
        listing_id,
        date AS potential_start_date,
        COALESCE(minimum_nights, 1) AS minimum_nights,
        maximum_nights,
        COUNT(*) OVER (
            PARTITION BY listing_id, island_group
            ORDER BY date
            ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
        ) AS remaining_nights
    FROM consecutive_islands
),

--#5: For each potential start date, the longest valid stay is limited
-- by remaining nights and that night's maximum_nights.
possible_stays AS (
    SELECT
        listing_id,
        potential_start_date,
        minimum_nights,
        LEAST(
            remaining_nights,
            COALESCE(maximum_nights, remaining_nights)
        ) AS possible_stay_length
    FROM remaining
),

--#6: Select the longest valid stay for each listing.
-- A start date only counts if possible_stay_length also meets minimum_nights.
max_stays AS (
    SELECT
        listing_id,
        MAX(possible_stay_length) AS longest_possible_stay
    FROM possible_stays
    WHERE possible_stay_length >= minimum_nights
    GROUP BY listing_id
)

--#7: Final output.
SELECT *
FROM max_stays
