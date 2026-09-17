{{
    config(
        materialized = "table"
    )
}}

WITH target_listings AS (
    -- Step 1: Filter for picky renter's required amenities
    SELECT listing_id
    FROM {{ ref('stg_listings') }}
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

available_days AS (
    -- Step 2: Get only the available days for those specific listings
    SELECT 
        c.listing_id,
        CAST(c.date AS DATE) AS date,
        c.maximum_nights
    FROM {{ ref('stg_calendar') }} AS c
    INNER JOIN target_listings AS l
        ON c.listing_id = l.listing_id
    WHERE c.is_available = TRUE
),

consecutive_islands AS (
    -- Step 3: Gaps and Islands Logic
    SELECT 
        listing_id,
        date,
        maximum_nights,
        DATE_SUB(date, INTERVAL ROW_NUMBER() OVER (PARTITION BY listing_id ORDER BY date ASC) DAY) AS island_group
    FROM available_days
),

island_durations AS (
    -- Step 4: Count the length of each consecutive window
    SELECT 
        listing_id,
        island_group,
        COUNT(date) AS consecutive_available_days,
        MAX(maximum_nights) AS maximum_nights_allowed 
    FROM consecutive_islands
    GROUP BY 1, 2
)

-- Step 5: Find the maximum valid stay per listing
SELECT 
    listing_id,
    MAX(LEAST(consecutive_available_days, maximum_nights_allowed)) AS longest_possible_stay
FROM island_durations
GROUP BY 1
ORDER BY longest_possible_stay DESC