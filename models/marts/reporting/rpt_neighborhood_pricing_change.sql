-- #2 - Neighborhood Pricing Change:
-- Write a query to find the YoY average price changes per neighborhood.

{{
    config(
        materialized = "table"
    )
}}

--#1: Begin by bringing in the core daily performance mart.
WITH 
    fct_daily_listing_performance AS (SELECT * FROM {{ ref('fct_daily_listing_performance') }}),

--#2: Isolate the baseline prices for the historical comparison date.
    prices_past AS (
        SELECT 
            listing_id,
            neighborhood,
            price AS price_past
        FROM fct_daily_listing_performance
        WHERE date = CAST('{{ var("pricing_compare_date_past") }}' AS DATE)
    ),

--#3: Isolate the recent prices for the current comparison date.
    prices_recent AS (
        SELECT 
            listing_id,
            price AS price_recent
        FROM fct_daily_listing_performance
        WHERE date = CAST('{{ var("pricing_compare_date_recent") }}' AS DATE)
    ),

--#4: Join the two time periods together to ensure we only analyze listings active on both dates.
    combined_prices AS (
        SELECT 
            p.neighborhood,
            p.listing_id,
            p.price_past,
            r.price_recent
        FROM prices_past AS p
        INNER JOIN prices_recent AS r
            ON p.listing_id = r.listing_id
    ),

--#5: Aggregate the metrics at the neighborhood grain.
    neighborhood_aggregates AS (
        SELECT 
            neighborhood,
            COUNT(listing_id) AS total_listings,
            AVG(price_past) AS avg_price_2021,
            AVG(price_recent) AS avg_price_2022,
            AVG(price_recent) - AVG(price_past) AS avg_price_increase
        FROM combined_prices
        GROUP BY 1
    ),

--#6: Make use of our final CTE.
    final AS (
        SELECT *
        FROM neighborhood_aggregates
        ORDER BY avg_price_increase DESC
    )

--#7: Final output.
    SELECT *
    FROM final