# dbt_jira v0.6.0
## 🚨 Breaking Changes 🚨
- This release of the `dbt_jira` packages implements changes to the incremental logic within various models highlighted in the Bug Fixes section below. As such, a `dbt run --full-refresh` will be required after upgrading this dependency for this package in your `packages.yml`.
## Bug Fixes
- Corrected CTE references within `int_jira__issue_assignee_resolution`. The final cte referenced was previously selecting from `issue_field_history` when it should have been selecting from `filtered`. ([#45](https://github.com/fivetran/dbt_jira/pull/45))
- Modified the incremental logic within `int_jira__agg_multiselect_history` to properly capture latest record. Previously, this logic would work for updates made outside of 24 hours. This logic update will now capture any changes since the previous dbt run. ([#48](https://github.com/fivetran/dbt_jira/pull/48))
## Under the Hood
- Modified the `int_jira__issue_calendar_spine` model to use the `dbt-utils.current_timestamp_in_utc` to better capture the current datetime across regions. ([#47](https://github.com/fivetran/dbt_jira/pull/47))

# dbt_jira v0.1.0 -> v0.5.1
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!