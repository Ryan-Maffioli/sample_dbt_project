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
    capacity_accomodated,
    bedrooms,
    beds,
    listing_price AS baseline_price,
    review_count,
    listing_ratings
FROM {{ ref('stg_listings') }}