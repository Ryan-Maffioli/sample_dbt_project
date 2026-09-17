-- #1 - Amenity Revenue
-- Write a query to find the total revenue and percentage of revenue by month segmented
-- by whether or not air conditioning exists on the listing.
-- Tip: For example, only 21.2% of revenue in July 2022 came from listings without air
-- conditioning.

{{
    config(
        materialized = "table"
    )
}}

--#1: We are going to start by bringing in the staging layer models we will need to use.
WITH 
    stg_listings AS (SELECT * FROM {{ref('stg_listings')}}),
    stg_calendar AS (SELECT * FROM {{ref('stg_calendar')}}),

--#2: The next step is to isolate the listing_ids that are tied to listings which due in fact have air coditioning.
    listings_with_ac_flag AS (
        SELECT 
            listing_id,
            EXISTS (
                SELECT 1 
                FROM UNNEST(JSON_EXTRACT_STRING_ARRAY(amenities)) AS amenity 
                WHERE LOWER(amenity) = 'air conditioning'
            ) AS has_ac
        FROM stg_listings
    ),

--#3: Now let's pull our revenue data from stg_calendar (where data is not available indicating a booking).
--#3B: Revenue in this dataset comes from non-available days (available = 'f' / reservation_id IS NOT NULL)
--#3C: Aggregate monthly revenue by AC status
    monthly_revenue AS (
        SELECT 
            DATE_TRUNC(c.date, MONTH) AS month,
            l.has_ac,
            SUM(c.price) AS total_revenue
        FROM stg_calendar AS c
        INNER JOIN listings_with_ac_flag AS l
            ON c.listing_id = l.listing_id
        WHERE c.is_available = FALSE  -- Only booked days count toward revenue
        GROUP BY 1, 2
    ),

--#4: We're then going to calculate our total & running totals.
pct_totals AS (
SELECT 
    month,
    has_ac,
    total_revenue,
    SUM(total_revenue) OVER (PARTITION BY month) AS monthly_total_revenue,
    ROUND(
        SAFE_DIVIDE(total_revenue, SUM(total_revenue) OVER (PARTITION BY month)) * 100, 
        1
    ) AS pct_of_monthly_revenue
FROM monthly_revenue
ORDER BY month ASC, has_ac DESC
),

final AS (
    SELECT *
    FROM pct_totals
)

SELECT *
FROM final