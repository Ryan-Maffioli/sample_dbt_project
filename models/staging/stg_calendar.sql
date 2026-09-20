{{
    config(
        materialized = "table",
        cluster_by = ["listing_id", "date"]
    )
}}

--#1: Start by bringing in the source table(s) we are going to need.
WITH 
    source_calendar AS (SELECT * FROM {{ source('source_calendar', 'calendar') }}),

--#2: Do some basic renaming to make this a little bit more friendly.
--#2B: Normalize AVAILABLE to a true boolean (handles t/f strings and native BOOL).
--#2C: Parse PRICE to numeric so $ strings and already-numeric values both work downstream.
    cleaned AS (
        SELECT 
            LISTING_ID                          AS listing_id,
            DATE                                AS date,
            {{ parse_tf_boolean('available') }} AS is_available,
            RESERVATION_ID                      AS reservation_id, 
            {{ parse_money('price') }}          AS price,
            MINIMUM_NIGHTS                      AS minimum_nights,
            MAXIMUM_NIGHTS                      AS maximum_nights
        FROM source_calendar
        WHERE 1=1 
        AND listing_id IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY listing_id, date ORDER BY {{ parse_money('price') }} DESC) = 1 
        --Tie-breaker: selects highest price if duplicate entries exist.
        --Given listing_id = 1303261 is the only duplicate entry, and it is a true 1:1 byte dupe, using price as a tie breaker is better than arbitrarily just choosing a record. 
    ),

--#3: Make use of a final cte (per dbt best practices). Makes dqa easier if ever need be.
    final AS (
        SELECT *
        FROM cleaned
    )

--#4: Final output.
    SELECT *
    FROM final
