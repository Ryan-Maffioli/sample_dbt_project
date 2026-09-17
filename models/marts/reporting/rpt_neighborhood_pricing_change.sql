-- Write a query to find the average price increase for each neighborhood from July 12th
-- 2021 to July 11th 2022.
-- Tip: For example, the Back Bay neighborhood only has one listing, so the difference of $44 is
-- the average for the whole neighborhood based solely on listing 10813.
{{
    config(
        materialized = "table"
    )
}}


--#1: Start by bringing in the staging layer tables we are going to need.
WITH 
    stg_listings AS (SELECT * FROM {{ref('stg_listings')}}),
    stg_calendar AS (SELECT * FROM {{ref('stg_calendar')}}),

--#2: Next the prompt gives us explicit dates to look between, so let's filter to that data only.
--#2B: We'll look specifically at the calendar table in that date range.
    target_dates AS (
        SELECT 
            listing_id,
            date,
            price 
        FROM stg_calendar
        WHERE 1=1
        AND DATE BETWEEN '2021-07-12' AND '2022-07-11'
    ),

--#3: Then we'll go ahead and pull the prices at the start & end dates.
    listing_price_changes AS (
        SELECT 
            l.neighborhood,
            c.listing_id,
            MAX(CASE WHEN c.date = DATE '2021-07-12' THEN c.price END) AS price_2021,
            MAX(CASE WHEN c.date = DATE '2022-07-11' THEN c.price END) AS price_2022
        FROM target_dates AS c
        INNER JOIN stg_listings AS l
            ON c.listing_id = l.listing_id
        GROUP BY 1, 2
        -- Ensure the listing existed on both dates for a valid comparison
        HAVING price_2021 IS NOT NULL AND price_2022 IS NOT NULL
    ),

-- Step 3: Aggregate average price increase per neighborhood
aggregated AS (
    SELECT 
        neighborhood,
        COUNT(listing_id) AS total_listings,
        ROUND(AVG(price_2021), 2) AS avg_price_2021,
        ROUND(AVG(price_2022), 2) AS avg_price_2022,
        ROUND(AVG(price_2022 - price_2021), 2) AS avg_price_increase
    FROM listing_price_changes
    GROUP BY 1
    ORDER BY avg_price_increase DESC
)

SELECT *
FROM aggregated
