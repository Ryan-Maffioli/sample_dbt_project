{{
    config(
        materialized = "table"
    )
}}

--#1: Start by bringing in the upstream materializations we are going to need.
WITH 
    stg_listings AS (SELECT * FROM {{ ref('stg_listings') }}),
    stg_calendar AS (SELECT * FROM {{ ref('stg_calendar') }}),

--#2: Next we will filter for picky renter's required amenities.
    target_listings AS (
        SELECT listing_id
        FROM stg_listings
        WHERE EXISTS (
            SELECT 1 
            FROM UNNEST(JSON_EXTRACT_STRING_ARRAY(amenities)) AS amenity 
            WHERE LOWER(amenity) = 'lockbox'
        )
        AND EXISTS (
            SELECT 1 
            FROM UNNEST(JSON_EXTRACT_STRING_ARRAY(amenities)) AS amenity 
            WHERE LOWER(amenity) = 'first aid kit'
        )
    ),

--#3: Grab only the available days for those specific listings.
    available_days AS (
        SELECT 
            c.listing_id,
            CAST(c.date AS DATE) AS date,
            c.maximum_nights
        FROM stg_calendar AS c
        INNER JOIN target_listings AS l
            ON c.listing_id = l.listing_id
        WHERE c.is_available = TRUE
    ),

--#4: Create our gaps logic.
--#4B: Consecutive Days Keep the Same Anchor Date: When dates advance by 1 day (+1) and ROW_NUMBER() simultaneously advances by 1 (+1), subtracting the two cancels out the daily increase. 
--#4C: Every consecutive day in an uninterrupted streak calculates to the exact same anchor date.
--#4D: Gaps Trigger a New Group. 
--#4E: When a gap occurs (e.g., jumping from July 3 to July 6), the date jumps ahead by 3 days while ROW_NUMBER() only increases by 1. 
--#4F: This imbalance shifts the calculated date backward, creating a brand-new island_group identifier.
    consecutive_islands AS (
        -- Step 3: Gaps and Islands Logic
        SELECT 
            listing_id,
            date,
            maximum_nights,
            DATE_SUB(date, INTERVAL ROW_NUMBER() OVER (PARTITION BY listing_id ORDER BY date ASC) DAY) AS island_group
        FROM available_days
    ),

--#5: Count the length of each consecutive window.
    island_durations AS (
        SELECT 
            listing_id,
            island_group,
            COUNT(date) AS consecutive_available_days,
            MAX(maximum_nights) AS maximum_nights_allowed 
        FROM consecutive_islands
        GROUP BY 1, 2
    ),

--#6: Find the maximum valid stay per listing.
    longest_stay AS (
        SELECT 
            listing_id,
            MAX(LEAST(consecutive_available_days, maximum_nights_allowed)) AS longest_possible_stay
        FROM island_durations
        GROUP BY 1
        ORDER BY longest_possible_stay DESC
    ),

--#7: Make use of a final CTE.
    final AS (
        SELECT *
        FROM longest_stay
    )

--#8: Final output.
    SELECT *
    FROM final