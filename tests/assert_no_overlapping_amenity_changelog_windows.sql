-- Singular Test: Assert no overlapping or inverted validity windows exist per listing.
-- Fails if identical change_ts timestamps or non-deterministic LEAD ordering create window overlaps.
-- One-day windows (valid_from = valid_to) are valid and must not fail.

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
    --#1: Inverted window (valid_from occurs after valid_to). Equal dates are a valid one-day window.
    valid_from > valid_to
    --#2: Overlap where current span starts on or before the previous span closed (inclusive BETWEEN).
    OR (prev_valid_to IS NOT NULL AND valid_from <= prev_valid_to)
