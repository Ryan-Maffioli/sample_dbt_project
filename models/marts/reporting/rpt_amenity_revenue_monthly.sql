-- #1 - Amenity Revenue:
-- Write a query to find the total revenue and percentage of revenue by month segmented by whether or not air conditioning exists on the listing.
-- Tip: For example, only 21.2% of revenue in July 2022 came from listings without air conditioning.

{{
    config(
        materialized = "table"
    )
}}

--#1: We are going to start by bringing in the core daily fact table containing point-in-time amenity flags.
WITH 
    fct_daily_listing_performance AS (SELECT * FROM {{ref('fct_daily_listing_performance')}}),

--#2: Now let's aggregate revenue by month and point-in-time AC status for booked dates (is_available = FALSE).
    monthly_revenue AS (
        SELECT 
            DATE_TRUNC(date, MONTH) AS month,
            has_ac,
            SUM(price) AS total_revenue
        FROM fct_daily_listing_performance
        WHERE is_available = FALSE  -- Only booked days count toward revenue.
        GROUP BY 1, 2
    ),

--#3: We're then going to calculate total monthly revenue and percentage split per AC segment.
    pct_totals AS (
        SELECT 
            month,
            has_ac,
            total_revenue,
            SUM(total_revenue) OVER (PARTITION BY month) AS monthly_total_revenue,
            ROUND(SAFE_DIVIDE(total_revenue, SUM(total_revenue) OVER (PARTITION BY month)) * 100, 1) AS pct_of_monthly_revenue
        FROM monthly_revenue
        ORDER BY month ASC, has_ac DESC
    ),

--#4: Make use of our final CTE.
    final AS (
        SELECT *
        FROM pct_totals
    )

--#5: Final output.
    SELECT *
    FROM final