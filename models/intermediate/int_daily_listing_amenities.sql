{{
    config(
        materialized = "table"
    )
}}

--#1: Start by bringing in all the upstream materializations we are going to need.
WITH 
    stg_calendar AS (SELECT * FROM {{ ref('stg_calendar') }}), 
    stg_listings AS (SELECT * FROM {{ ref('stg_listings') }}),
    int_amenities_changelog_spanned AS (SELECT * FROM {{ ref('int_amenities_changelog_spanned') }}),

--#2: To start transforming, we are going to create a list of every unique listing_id & date combination.
    calendar_dates AS (
    SELECT DISTINCT
        listing_id,
        date   
    FROM stg_calendar
),

--#3: Then from our listings table, we'll extract all the amenities that we can tie to each listing_id.
--#3B: Parsed/trimmed the same way as changelog arrays so COALESCE compares like types.
    listings AS (
        SELECT 
            listing_id                             AS listing_id,
            {{ parse_amenity_array('amenities') }} AS baseline_amenities
        FROM stg_listings
    ),

--#4: Now that we have all of our CTEs processed & ready, we can start combining the data.
    transformed AS (
    SELECT 
        c.listing_id,
        c.date,    
        COALESCE(ch.amenities, l.baseline_amenities) AS amenities
        --Prioritizes active changelog array; falls back to static baseline array.
        --NULL when neither a covering window nor a listing baseline exists.
    FROM calendar_dates AS c
    LEFT JOIN listings AS l
        ON c.listing_id = l.listing_id
    LEFT JOIN int_amenities_changelog_spanned AS ch
        ON c.listing_id = ch.listing_id
        AND c.date BETWEEN ch.valid_from AND ch.valid_to
    ),

--#5: Make use of a final CTE.
    final AS (
        SELECT *
        FROM transformed
    )

--#6: Final output.
    SELECT *
    FROM final
