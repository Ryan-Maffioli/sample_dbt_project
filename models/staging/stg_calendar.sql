{{
    config(
        materialized = "table"
    )
}}
WITH 
    source_calendar AS (SELECT * FROM {{source('source_calendar', 'calendar')}}),

    cleaned AS (
        SELECT 
            LISTING_ID AS listing_id,
            DATE AS date,
            AVAILABLE AS is_available,
            RESERVATION_ID AS reservation_id, 
            PRICE AS price,
            MINIMUM_NIGHTS AS minimum_nights,
            MAXIMUM_NIGHTS AS maximum_nights
        FROM source_calendar
    )

    SELECT *
    FROM cleaned