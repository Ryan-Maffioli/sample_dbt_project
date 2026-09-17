{{
    config(
        materialized = "table"
    )
}}
WITH 
    source_amenitites_changelog AS (SELECT * FROM {{source('source_amenities_changelog', 'amenities_changelog')}}),

    cleaned AS (
        SELECT 
            LISTING_ID AS listing_id,
            CHANGE_AT AS change_ts,
            AMENITIES AS amenities
        FROM source_amenitites_changelog
    )

    SELECT *
    FROM cleaned