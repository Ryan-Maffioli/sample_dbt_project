{{
    config(
        materialized = "table",
        cluster_by = ["neighborhood"]
    )
}}

--#1: Begin by bringing in the upstream models we are going to need.
WITH 
    stg_calendar AS (
        SELECT * 
        FROM {{ ref('stg_calendar') }}
        
        -- JINJA LOGIC: On incremental runs, only process the trailing 3 days 
        -- to account for late-arriving bookings or availability updates.
        -- Removed due to BQ limitation on free DDL processing.
        -- {% if is_incremental() %}
        -- WHERE date >= (SELECT DATE_SUB(MAX(date), INTERVAL 3 DAY) FROM {{ this }})
        -- {% endif %}
    ),
    
    daily_amenities AS (SELECT * FROM {{ ref('int_daily_listing_amenities') }}),
    dim_listings    AS (SELECT * FROM {{ ref('dim_listings') }}),

--#2: We'll limit our listings data to just the fields we need.
    listings AS (
        SELECT 
            listing_id,
            neighborhood
        FROM dim_listings
    ),

--#3: Now, we are going to combine our calendar, amenities, and listings data.
--#3B: In this CTE, we are also going to flag the ac, lockbox, and first aid amenities.
    transformed AS (
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
            
            --Pre-calculated boolean flags for high-frequency queries.
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

        FROM stg_calendar AS c
        INNER JOIN listings AS l
            ON c.listing_id = l.listing_id
        LEFT JOIN daily_amenities AS a
            ON c.listing_id = a.listing_id
        AND c.date = a.date
    ),

--#4: Make use of our final CTE.
    final AS (
        SELECT *
        FROM transformed
    )

--#5: Final output.
    SELECT *
    FROM final