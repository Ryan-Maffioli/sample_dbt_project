WITH changelog AS (
    SELECT 
        listing_id,
        CAST(change_ts AS DATE) AS valid_from,
        JSON_EXTRACT_STRING_ARRAY(amenities) AS amenities
    FROM {{ ref('stg_amenities_changelog') }}
),

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
)

SELECT * FROM spanned