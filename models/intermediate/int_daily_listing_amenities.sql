WITH calendar_dates AS (
    SELECT DISTINCT
        listing_id,
        CAST(date AS DATE) AS date
    FROM {{ ref('stg_calendar') }}
),

listings AS (
    SELECT 
        listing_id,
        JSON_EXTRACT_STRING_ARRAY(amenities) AS baseline_amenities
    FROM {{ ref('stg_listings') }}
),

changelog_spanned AS (
    SELECT * FROM {{ ref('int_amenities_changelog_spanned') }}
)

SELECT 
    c.listing_id,
    c.date,
    -- Prioritizes active changelog array; falls back to static baseline array
    COALESCE(ch.amenities, l.baseline_amenities) AS amenities
FROM calendar_dates AS c
LEFT JOIN listings AS l
    ON c.listing_id = l.listing_id
LEFT JOIN changelog_spanned AS ch
    ON c.listing_id = ch.listing_id
   AND c.date BETWEEN ch.valid_from AND ch.valid_to