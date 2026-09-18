{{
    config(
        materialized = "table"
    )
}}

--#1: We will start by bringing in the staging table(s) we are going to need.
WITH 
    stg_amenities_changelog AS (SELECT * FROM {{ ref('stg_amenities_changelog') }}),

--#2: We are going to transform this staging model into a table that uses a valid_from & valid_to design.
--#2B: As such, we'll grab the listing_id, create the valid_from, and extract the amenitites.
changelog AS (
    SELECT 
        listing_id,
        CAST(change_ts AS DATE) AS valid_from,
        JSON_EXTRACT_STRING_ARRAY(amenities) AS amenities
    FROM stg_amenities_changelog
),

--#3: Then we will work in the other direction, building out the valid_to.
--#3B: Similarly, we'll grabthe listing_id, amenitites,valid_from (calculated above), and write a bit of custom logic for the valid_to.
--#3C: In the event the valid_to represents a still active row, 9999-12-31 helps to relay that information.
spanned AS (
    SELECT
        listing_id,
        amenities,
        valid_from,
        -- Sets valid_to as 1 day before the next change, or 9999-12-31 if active version
        COALESCE(
            DATE_SUB(LEAD(valid_from) OVER (PARTITION BY listing_id ORDER BY valid_from ASC), INTERVAL 1 DAY),
            DATE '9999-12-31'
        ) AS valid_to
    FROM changelog
),

--#4: Make use of our customary final CTE.
    final AS (
    SELECT * 
    FROM spanned
    )

--#5: Final output.
    SELECT *
    FROM final