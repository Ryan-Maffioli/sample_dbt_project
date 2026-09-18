{% docs amenity_has_ac %}
Boolean flag indicating whether 'Air Conditioning' was present in the listing's active amenities array on this specific date. This is a point-in-time calculation derived from the historical changelog.
{% enddocs %}

{% docs amenity_has_lockbox %}
Boolean flag indicating whether 'Lockbox' was present in the listing's active amenities array on this specific date. This is a point-in-time calculation derived from the historical changelog.
{% enddocs %}

{% docs amenity_has_first_aid_kit %}
Boolean flag indicating whether 'First aid kit' was present in the listing's active amenities array on this specific date. This is a point-in-time calculation derived from the historical changelog.
{% enddocs %}

{% docs fct_daily_listing_performance_architecture %}
### Materialization Strategy & Sandbox Constraints

* **Current State (Sandbox Tier):** Materialized as a standard `table` clustered on `(listing_id, neighborhood)` without `partition_by`.
* **BigQuery Free Tier Limitation:** BigQuery Sandbox enforces a mandatory maximum default partition expiration of 60 days on unbilled projects. Because this dataset contains historical calendar dates (e.g., 2021 data), applying `partition_by` causes BigQuery to automatically purge historical partitions upon creation (resulting in 0 rows), while attempting to override it via `partition_expiration_days = none` triggers a billing requirement error.
* **Production Deployment Path:** In a paid GCP environment, re-enable partitioning on the `date` field:
  * **Table Materialization:** `partition_by = {"field": "date", "data_type": "date", "granularity": "month"}` with `partition_expiration_days = none`.
  * **Incremental Strategy:** Convert to `materialized='incremental'` using `incremental_strategy='insert_overwrite'` with `granularity='day'` to allow point-in-time daily partition updates without full table scans.
{% enddocs %}