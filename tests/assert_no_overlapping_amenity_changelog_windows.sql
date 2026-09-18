-- Singular Test: Assert no overlapping or zero-length validity windows exist per listing.
-- Fails if identical change_ts timestamps or non-deterministic LEAD ordering create window overlaps.

WITH window_checks AS (
    SELECT
        listing_id,
        valid_from,
        valid_to,
        LAG(valid_to) OVER (PARTITION BY listing_id ORDER BY valid_from ASC, valid_to ASC) AS prev_valid_to
    FROM {{ ref('int_amenities_changelog_spanned') }}
)

SELECT
    listing_id,
    valid_from,
    valid_to,
    prev_valid_to
FROM window_checks
WHERE 
    -- 1. Zero-length or inverted window (valid_from occurs on or after valid_to)
    (valid_to IS NOT NULL AND valid_from >= valid_to)
    -- 2. Overlap where current span starts before previous span closed
    OR (prev_valid_to IS NOT NULL AND valid_from < prev_valid_to)