# Rental Property Analytics - dbt Project

Transforms raw rental listing, calendar, and amenity-changelog source data
into a daily listing-grain fact table and three reporting marts answering
revenue, pricing, and stay-length business questions.

## Requirements

- dbt-core (see `dbt_project.yml` for the version this was built against)
- BigQuery adapter (`dbt-bigquery`)
- [dbt-utils](https://github.com/dbt-labs/dbt-utils) `1.1.1` - installed via `dbt deps` (see `packages.yml`)

## Getting started

```bash
dbt deps      # installs dbt-utils
dbt build     # runs models + tests
```

To regenerate and view docs (including the data-quality notes referenced below):

```bash
dbt docs generate
dbt docs serve
```

## Data sources

Three raw tables, documented in `models/source/`:

| Source | Grain | Notes |
|---|---|---|
| `listings` | one row per listing | host/property metadata, baseline amenities and price |
| `calendar` | one row per listing per date | availability, price, reservation, min/max nights |
| `amenities_changelog` | one row per amenity update event | full amenity list as of each change, not a diff |

## Architecture

```
source → staging → intermediate → core marts → reporting
```

| Layer | Models | Materialization |
|---|---|---|
| Staging | `stg_listings`, `stg_calendar`, `stg_amenities_changelog` | views (`stg_calendar` is a table - see below) |
| Intermediate | `int_amenities_changelog_spanned`, `int_daily_listing_amenities` | tables |
| Core marts | `dim_listings`, `fct_daily_listing_performance` | `dim_listings` is a view; `fct_daily_listing_performance` is a clustered table |
| Reporting | `rpt_amenity_revenue_monthly`, `rpt_neighborhood_pricing_change`, `rpt_picky_renter_longest_stay` | tables |

`stg_calendar` is a table rather than a view because it deduplicates
listing/date rows (see Assumptions) - that logic shouldn't be recomputed on
every downstream query. Every other staging model is a thin rename/cast
pass and stays a view.

## Business questions → reporting models

| Question | Model |
|---|---|
| Revenue and % of revenue by month, segmented by AC | `rpt_amenity_revenue_monthly` |
| Average price change per neighborhood between two dates | `rpt_neighborhood_pricing_change` |
| Longest possible stay for listings with both lockbox and first aid kit | `rpt_picky_renter_longest_stay` |

All three read from `fct_daily_listing_performance` rather than
re-deriving amenity/price logic from staging, so amenity and revenue
definitions stay consistent across reports.

## Key modeling decisions

**Daily listing grain.** `fct_daily_listing_performance` is one row per
`listing_id` and `date`. Neighborhood is denormalized from `dim_listings`
at build time.

**Point-in-time amenities.** Changelog records are treated as complete
amenity configurations, not diffs. Same-day changes keep the latest
timestamp. Windows are inclusive (`valid_from` through `valid_to`); a
one-day window is valid. Dates before the first changelog window use the
listing's baseline amenity array; dates covered by a window use that
window. Listings with neither a baseline nor a covering window have null
amenities and null amenity flags (unknown, not `false`).

**Revenue.** A calendar date counts as booked revenue when
`reservation_id` is not null; revenue is the nightly `price` on that date.
Cleaning fees, taxes, and other charges aren't in the source data. Blocked
nights (unavailable, no reservation) aren't revenue. Nights with unknown
AC status are excluded from the AC revenue split rather than scored as
"no AC."

**Longest possible stay.** A continuous stay requires every date in the
interval to be available, with both lockbox and first aid kit present on
each of those dates. From each possible start date, the stay length is the
remaining nights in that availability island, capped by that night's
`maximum_nights`, and only counted if it also meets `minimum_nights`.

**Materialization: `fct_daily_listing_performance`.** Clustered on
`(date, listing_id)`, no `partition_by` in this sandbox tier - BigQuery
Sandbox's default 60-day partition expiration would silently purge this
dataset's 2021 history. Full reasoning and the production-tier path
(`partition_by` + `insert_overwrite` incremental) are documented in the
model's docs block (`fct_daily_listing_performance_architecture`).

**Materialization: `stg_calendar`.** Clustered on `(listing_id, date)` - the
opposite column order from `fct_daily_listing_performance`'s
`(date, listing_id)`. Each table is clustered for its own primary access
pattern rather than copied from the other: `stg_calendar` is consumed
almost entirely through equi-joins on `(listing_id, date)` by
`int_daily_listing_amenities` and `fct_daily_listing_performance`, while
`fct_daily_listing_performance` is consumed by reporting queries that
filter/aggregate by date range first. No `partition_by` here either, for
the same Sandbox-tier reason as `fct` - this table covers the same
2021-2022 date range. In practice, clustering has no measurable effect at
this dataset's size; it's included to match the production-scale access
pattern rather than for an observed performance gain here.

## Testing strategy

- Grain is enforced with `dbt_utils.unique_combination_of_columns` on
  every intermediate and core model, not just single-column `unique`
  tests, since none of them have a natural single-column key.
- `is_available`/`price`/`neighborhood` etc. get `not_null` +
  `accepted_values`/range checks where a null or out-of-range value would
  indicate a real upstream problem.
- Foreign-key (`relationships`) tests between staging/fct and
  `stg_listings`/`dim_listings` are set to `severity: warn`, not error -
  see Known Data Issues below for why.
- One singular test, `assert_no_overlapping_amenity_changelog_windows`,
  guards against non-deterministic window spanning if the changelog ever
  contains duplicate-timestamp events for the same listing.

## Known data issues

**`listing_id` 276450** appears in `stg_calendar` (365 rows, $76,520 in
booked revenue) and `stg_amenities_changelog`, but has no matching row in
`stg_listings`. Investigated and most likely a source-side load gap rather
than fabricated/test data (full investigation trail - including a ruled-out
synthetic-record hypothesis - in the `listing_id_276450` docs block on
`fct_daily_listing_performance`). Its calendar activity is preserved via a
`LEFT JOIN` rather than dropped; neighborhood and amenity fields are null
for it since they can't be resolved. This is why the `relationships` tests
above are `warn`, not `error` - the gap is known, investigated, and an
intentional design choice rather than an unhandled failure.

## Assumptions

- Null listing IDs in the extract are excluded in staging.
- Duplicate calendar rows for the same listing and date keep the highest
  price (only one listing in this dataset has this issue - a true 1:1
  byte-duplicate - so price is a defensible tie-breaker over an arbitrary
  pick).
- `minimum_nights`/`maximum_nights` reflect listing configuration as of the
  source extract, not necessarily the rule enforced at the time of each
  historical reservation.
- Comparison dates for neighborhood pricing are set via vars
  (`pricing_compare_date_past`, `pricing_compare_date_recent` - defaults
  `2021-07-12` and `2022-07-11`) rather than hardcoded in SQL, so the
  report can be re-run for a different window without a code change.