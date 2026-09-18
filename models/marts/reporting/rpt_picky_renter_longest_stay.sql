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

--#2: Next, we isolate the available days for listings that currently have both a lockbox and a first aid kit.
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

--#3: We apply Gaps and Islands logic to group consecutive available days into unique islands.
    consecutive_islands AS (
        SELECT 
            listing_id,
            date,
            maximum_nights,
            DATE_SUB(date, INTERVAL ROW_NUMBER() OVER (PARTITION BY listing_id ORDER BY date ASC) DAY) AS island_group
        FROM qualified_available_days
    ),

--#4: Now we aggregate these islands to calculate the length of each continuous streak.
    island_aggregates AS (
        SELECT
            listing_id,
            island_group,
            COUNT(date) AS streak_length,
            MIN(maximum_nights) AS max_nights_limit
        FROM consecutive_islands
        GROUP BY 1, 2
    ),

--#5: Find the maximum stay per listing, capped by the host's maximum_nights policy.
    max_stays AS (
        SELECT
            listing_id,
            MAX(LEAST(streak_length, max_nights_limit)) AS longest_possible_stay
        FROM island_aggregates
        GROUP BY 1
    ),

--#6: Make use of our final CTE.
    final AS (
        SELECT *
        FROM max_stays
        ORDER BY longest_possible_stay DESC
    )

--#7: Final output.
    SELECT *
    FROM final