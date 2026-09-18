{{
    config(
        materialized = "view"
    )
}}

--#1: Start by bringing in the upstream materializations we are going to need.
WITH 
    stg_listings AS (SELECT * FROM {{ ref('stg_listings') }}),

--#2: Choose the desired fields for our output.
    desired_output AS (
        SELECT
            listing_id,
            listing_name,
            host_id,
            host_name,
            host_since_ts,
            host_location,
            neighborhood,
            property_type,
            room_type,
            capacity_accommodated,
            bedrooms,
            beds,
            listing_price AS baseline_price,
            review_count,
            listing_ratings
        FROM stg_listings
    ),

--#3: Make use of a final CTE.
    final AS (
        SELECT *
        FROM desired_output
    )

--#4: Final output.
    SELECT *
    FROM final