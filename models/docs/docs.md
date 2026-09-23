{% docs amenity_has_ac %}
Boolean flag indicating whether 'Air Conditioning' was present in the listing's active amenities array on this date. Null when the amenity array is unknown (no changelog window and no listing baseline).
{% enddocs %}

{% docs amenity_has_lockbox %}
Boolean flag indicating whether 'Lockbox' was present in the listing's active amenities array on this date. Null when the amenity array is unknown.
{% enddocs %}

{% docs amenity_has_first_aid_kit %}
Boolean flag indicating whether 'First aid kit' was present in the listing's active amenities array on this date. Null when the amenity array is unknown.
{% enddocs %}

{% docs stg_calendar_architecture %}
### Materialization Strategy

* **Table, not view:** unlike other staging models, `stg_calendar`
  deduplicates listing/date rows via `QUALIFY ROW_NUMBER()`. That logic
  shouldn't be recomputed by every downstream query, so it's materialized
  as a table.
* **Clustered on `(listing_id, date)`:** matches the equi-join pattern used
  by every downstream consumer (`int_daily_listing_amenities`,
  `fct_daily_listing_performance`), rather than mirroring
  `fct_daily_listing_performance`'s `(date, listing_id)` clustering, which
  is instead optimized for that model's own date-range-filtered reporting
  queries.
* **No `partition_by`:** same BigQuery Sandbox 60-day partition expiration
  constraint documented in `fct_daily_listing_performance_architecture` -
  this table spans the same 2021-2022 date range and would lose historical
  partitions on creation.
{% enddocs %}

{% docs fct_daily_listing_performance_architecture %}
### Materialization Strategy & Sandbox Constraints

* **Current State (Sandbox Tier):** Materialized as a standard `table` clustered on `(date, listing_id)` without `partition_by`.
* **BigQuery Free Tier Limitation:** BigQuery Sandbox enforces a mandatory maximum default partition expiration of 60 days on unbilled projects. Because this dataset contains historical calendar dates (e.g., 2021 data), applying `partition_by` causes BigQuery to automatically purge historical partitions upon creation (resulting in 0 rows), while attempting to override it via `partition_expiration_days = none` triggers a billing requirement error.
* **Production Deployment Path:** In a paid GCP environment, re-enable partitioning on the `date` field:
  * **Table Materialization:** `partition_by = {"field": "date", "data_type": "date", "granularity": "month"}` with `partition_expiration_days = none`.
  * **Incremental Strategy:** Convert to `materialized='incremental'` using `incremental_strategy='insert_overwrite'` with `granularity='day'` to allow point-in-time daily partition updates without full table scans.
{% enddocs %}

{% docs listing_id_276450 %}

### Listing ID 276450: Data Integrity & Anomaly Notes

* **Data Presence:** Appears in `stg_calendar` (365 rows, 365 booked nights, $76,520 revenue) and `stg_amenities_changelog`, but has no corresponding row in `stg_listings`.
* **Investigation Findings:** Initially evaluated as a potential test record because its reservation lengths (8–10 nights) conflict with its stated `minimum_nights` rule (30). However, reservation IDs are unique and not reused across other listings, ruling out simple synthetic duplication.
* **Root Cause:** Most likely caused by a source-side load-order gap or a dropped row during ingestion, rather than fabricated data.
* **Downstream Behavior:** Calendar data is preserved via a `LEFT JOIN` in `fct_daily_listing_performance`. Neighborhood and amenity attributes evaluate to `NULL` since they cannot be resolved without the parent listing record.

### Schema & Historical Note
* `minimum_nights` and `maximum_nights` values reflect the listing configuration as of the source extract date, and do not necessarily represent the active rule enforced at the time of each historical reservation.

{% enddocs %}