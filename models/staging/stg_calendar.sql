{{
    config(
        materialized = "table"
    )
}}

--#1: Start by bringing in the source table(s) we are going to need.
WITH 
    source_calendar AS (SELECT * FROM {{source('source_calendar', 'calendar')}}),

--#2: Do some basicr renaming to make this a little bit more friendly.
    cleaned AS (
        SELECT 
            LISTING_ID     AS listing_id,
            DATE           AS date,
            AVAILABLE      AS is_available,
            RESERVATION_ID AS reservation_id, 
            PRICE          AS price,
            MINIMUM_NIGHTS AS minimum_nights,
            MAXIMUM_NIGHTS AS maximum_nights
        FROM source_calendar
    ),

--#3: Make use of a final cte (per dbt best practices). Makes dqa easier if ever need be.
    final AS (
    SELECT *
    FROM cleaned
    )

--#4: Final output.
    SELECT *
    FROM final