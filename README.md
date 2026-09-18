## Analytics Engineering Work

## Overview

This project transforms listing, calendar, and amenity changelog data
into a daily listing-level analytical mart and reporting models.

## Architecture

Source
  ↓
Staging
  ↓
Intermediate
  ↓
Core Marts
  ↓
Reporting

## Model Structure

stg_listings
stg_calendar
stg_amenities_changelog

        ↓

int_amenities_changelog_spanned
int_daily_listing_amenities

        ↓

dim_listings
fct_daily_listing_performance

        ↓

rpt_amenity_revenue_monthly
rpt_neighborhood_pricing_change
rpt_picky_renter_longest_stay

## Key Modeling Decisions

### Daily listing grain
...

### Point-in-time amenities
...

### Revenue
...

### Longest possible stay
...

## Testing

...

## Assumptions / Trade-offs

## Amenity changes

## The listings table represents the baseline amenity state.
## Changelog records represent subsequent complete amenity configurations.
## A changelog configuration supersedes the baseline configuration from its effective date onward.
## Multiple amenity changes occurring within the same day are handled according to X.

## Revenue

## A calendar date with a reservation represents one night of revenue.
## Revenue is calculated using the calendar price for that night.
## No cleaning fees, taxes, or other charges are represented in the provided source data.

## Availability

## A continuous stay requires every calendar date in the interval to be available.
## Maximum stay restrictions are applied according to X.


## Architecture
              ┌─────────────────┐
              │ source_listings │
              └────────┬────────┘
                       ↓
                 stg_listings
                       │
                       ↓
                  dim_listings
                       │
                       │
source_calendar → stg_calendar ──────┐
                                     ↓
source_amenities → stg_amenities → changelog_spanned
                                     ↓
                         daily_listing_amenities
                                     ↓
                         fct_daily_listing_performance
                              /        |        \
                             /         |         \
                            ↓          ↓          ↓
                       revenue     pricing    picky renter