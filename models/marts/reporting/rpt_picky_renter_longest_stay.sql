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
    fct_daily_listing_performance AS (SELECT * FROM {{ref('fct_daily_listing_performance')}}),
    
-- Isolate dates on which the listing satisfies all requirements.
qualified_available_days AS (
    SELECT
        listing_id,
        date,
        maximum_nights
    FROM fct_daily_listing_performance
    WHERE is_available = TRUE
      AND has_lockbox = TRUE
      AND has_first_aid_kit = TRUE
),

-- Gaps and Islands:
-- Consecutive dates will share the same island_group.
consecutive_islands AS (
    SELECT
        listing_id,
        date,
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

-- Determine the length of the continuous availability window
-- beginning from each possible start date.
streaks AS (
    SELECT
        listing_id,
        date AS potential_start_date,
        maximum_nights,
        COUNT(*) OVER (
            PARTITION BY listing_id, island_group
        ) AS available_streak_length
    FROM consecutive_islands
),

-- For each potential start date, the longest valid stay is limited
-- by both the continuous availability window and maximum_nights.
possible_stays AS (
    SELECT
        listing_id,
        potential_start_date,
        LEAST(
            available_streak_length,
            maximum_nights
        ) AS possible_stay_length
    FROM streaks
),

-- Select the longest valid stay for each listing.
max_stays AS (
    SELECT
        listing_id,
        MAX(possible_stay_length) AS longest_possible_stay
    FROM possible_stays
    GROUP BY listing_id
)

SELECT *
FROM max_stays