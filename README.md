## Analytics Engineering Work

This project transforms listing, calendar, and amenity changelog data
into a daily listing-level analytical mart and reporting models.

## Architecture

```
source → staging → intermediate → core marts → reporting
```

- `stg_listings`, `stg_calendar`, `stg_amenities_changelog`
- `int_amenities_changelog_spanned`, `int_daily_listing_amenities`
- `dim_listings`, `fct_daily_listing_performance`
- `rpt_amenity_revenue_monthly`, `rpt_neighborhood_pricing_change`, `rpt_picky_renter_longest_stay`

`stg_calendar` is a table because it deduplicates listing-date rows. Other
staging models are views.

## Key modeling decisions

### Daily listing grain

The fact is one row per listing and calendar date. Neighborhood is denormalized
from `dim_listings` at build time.

### Point-in-time amenities

Changelog records are treated as complete amenity configurations, not diffs.
Same-day changes keep the latest timestamp. Windows are inclusive
(`valid_from` through `valid_to`); a one-day window is valid.

Dates before the first changelog window use the listing baseline amenity
array. Dates covered by a window use that window. Listings with no baseline
and no covering window have null amenities and null amenity flags.

### Revenue

A calendar date counts as booked revenue when `reservation_id` is not null.
Revenue is the nightly `price` on that date. Cleaning fees, taxes, and other
charges are not in the source data. Blocked nights (unavailable, no
reservation) are not revenue. Nights with unknown AC status are excluded from
the AC revenue split.

### Longest possible stay

A continuous stay requires every calendar date in the interval to be available,
with both lockbox and first aid kit on those dates. From each start date the
length is remaining nights in that availability island, capped by that night's
`maximum_nights`, and only counted if it also meets `minimum_nights`.

## Assumptions

- Null listing IDs in the extract are excluded in staging.
- Duplicate calendar rows for the same listing and date keep the highest price.
- Comparison dates for neighborhood pricing are `pricing_compare_date_past`
  and `pricing_compare_date_recent` (defaults 2021-07-12 and 2022-07-11).
