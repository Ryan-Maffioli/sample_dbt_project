{{
    config(
        materialized = "table"
    )
}}

--#1: Start by bringing in the source table(s) we are going to need.
WITH 
    source_listings AS (SELECT * FROM {{source('source_listings', 'listings')}}),

--#2: Then we are just going to do some basic renaming to make this materialization a bit more friendly.
    cleaned AS (
        SELECT 
            ID                   AS listing_id,
            NAME                 AS listing_name,
            HOST_ID              AS host_id,
            HOST_NAME            AS host_name,
            HOST_SINCE           AS host_since_ts,
            HOST_LOCATION        AS host_location,
            HOST_VERIFICATIONS   AS host_verifications,
            NEIGHBORHOOD         AS neighborhood,
            PROPERTY_TYPE        AS property_type,
            ROOM_TYPE            AS room_type,
            ACCOMMODATES         AS capacity_accomodated,
            BATHROOMS_TEXT       AS bathrooms,
            BEDROOMS             AS bedrooms,
            BEDS                 AS beds,
            AMENITIES            AS amenities,
            PRICE                AS listing_price,
            NUMBER_OF_REVIEWS    AS review_count,
            FIRST_REVIEW         AS first_review_date,
            LAST_REVIEW          AS last_review_date,
            REVIEW_SCORES_RATING AS listing_ratings
        FROM source_listings
    ),

    --#3: Make use of a final CTE per dbt best practices (makes dqa easier if ever need be).
    final AS (
    SELECT *
    FROM cleaned
    )

    --#4: Final output.
    SELECT *
    FROM final

