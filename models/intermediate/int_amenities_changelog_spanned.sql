{{
    config(
        materialized = "table"
    )
}}

--#1: We will start by bringing in the staging table(s) we are going to need.
WITH 
    stg_amenities_changelog AS (SELECT * FROM {{ ref('stg_amenities_changelog') }}),

-- The reporting mart is at a daily grain, so if a listing has multiple
-- amenity changes on the same day, use the latest change from that day.
daily_changes AS (
    SELECT
        listing_id,
        CAST(change_ts AS DATE) AS valid_from,
        JSON_EXTRACT_STRING_ARRAY(amenities) AS amenities
    FROM stg_amenities_changelog
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY listing_id, CAST(change_ts AS DATE)
        ORDER BY change_ts DESC
    ) = 1
),

-- Build the effective date range for each amenity configuration.
spanned AS (
    SELECT
        listing_id,
        amenities,
        valid_from,
        COALESCE(
            DATE_SUB(
                LEAD(valid_from) OVER (
                    PARTITION BY listing_id
                    ORDER BY valid_from
                ),
                INTERVAL 1 DAY
            ),
            DATE '9999-12-31'
        ) AS valid_to
    FROM daily_changes
),

--#4: Make use of our customary final CTE.
    final AS (
    SELECT * 
    FROM spanned
    )

--#5: Final output.
    SELECT *
    FROM final