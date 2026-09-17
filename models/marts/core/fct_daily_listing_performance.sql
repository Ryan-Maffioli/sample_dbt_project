{{
    config(
        materialized = "table",
        partition_by = {
            "field": "date",
            "data_type": "date",
            "granularity": "month"
        },
        cluster_by = ["listing_id", "neighborhood"]
    )
}}

WITH calendar AS (
    SELECT * FROM {{ ref('stg_calendar') }}
),

listings AS (
    SELECT 
        listing_id,
        neighborhood
    FROM {{ ref('dim_listings') }}
),

daily_amenities AS (
    SELECT * FROM {{ ref('int_daily_listing_amenities') }}
)

SELECT 
    c.date,
    c.listing_id,
    l.neighborhood,
    c.reservation_id,
    c.is_available,
    c.price,
    c.minimum_nights,
    c.maximum_nights,
    a.amenities,
    
    -- Pre-calculated boolean flags for high-frequency queries
    EXISTS (
        SELECT 1 
        FROM UNNEST(a.amenities) AS item 
        WHERE LOWER(item) = 'air conditioning'
    ) AS has_ac,
    
    EXISTS (
        SELECT 1 
        FROM UNNEST(a.amenities) AS item 
        WHERE LOWER(item) = 'lockbox'
    ) AS has_lockbox,

    EXISTS (
        SELECT 1 
        FROM UNNEST(a.amenities) AS item 
        WHERE LOWER(item) = 'first aid kit'
    ) AS has_first_aid_kit

FROM calendar AS c
LEFT JOIN listings AS l
    ON c.listing_id = l.listing_id
LEFT JOIN daily_amenities AS a
    ON c.listing_id = a.listing_id
   AND c.date = a.date