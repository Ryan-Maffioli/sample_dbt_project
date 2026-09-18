{{
    config(
        materialized = "view"
    )
}}

--#1: Start by bringing in our necessary source table(s).
WITH 
    source_amenitites_changelog AS (SELECT * FROM {{ source('source_amenities_changelog', 'amenities_changelog') }}),

--#2: We'll do a little bit of renaming to make this materialization easier to use.
--#2B: Drop NULL listing_ids here so they never enter the spanned windows.
    cleaned AS (
        SELECT 
            LISTING_ID AS listing_id,
            CHANGE_AT  AS change_ts,
            AMENITIES  AS amenities
        FROM source_amenitites_changelog
        WHERE 1=1
        AND listing_id IS NOT NULL
    ),

--#3: Make use of a final CTE (per dbt best practices). This makes dqa easier if ever need be.
    final AS (
    SELECT *
    FROM cleaned
    )

--#4: Final Output.
    SELECT *
    FROM final
