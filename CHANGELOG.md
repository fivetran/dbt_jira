# dbt_jira v0.8.2
## Bug Fixes
- Corrected bug introduced in 0.8.0 that would prevent `sprint` data from being passed to model `jira__daily_issue_field_history`. ([#62](https://github.com/fivetran/dbt_jira/pull/62))


## Contributors
- [@troyschuetrumpf-elation](https://github.com/troyschuetrumpf-elation) ([#62](https://github.com/fivetran/dbt_jira/pull/62))

# dbt_jira v0.8.1
## Features
- Makes priority data optional. Allows new env var `jira_using_priorities`. Models `jira__issue_enhanced` and `int_jira__issue_join` won't require source `jira.priority` or contain priority-related columns if `jira_using_priorities: false`. ([#55](https://github.com/fivetran/dbt_jira/pull/55))

## Contributors
- @everettttt ([#55](https://github.com/fivetran/dbt_jira/pull/55))

# dbt_jira v0.8.0
## 🚨 Breaking Changes 🚨
- Previously the `jira__daily_field_history` and `jira__issue_enhanced` models allowed for users to leverage the `issue_field_history_columns` to bring through custom `field_id`s. However, the `field_id` was not very intuitive to report off. Therefore, the package has been updated to bring through the `field_name` values in the variable and persist through to the final models. ([#54](https://github.com/fivetran/dbt_jira/pull/54))
  - Please note, if you leveraged this variable in the past then you will want to update the `field_id` (customfield_000123) to be the `field_name` (Cool Custom Field) now. Further, a `dbt run --full-refresh` will be required as well.

## Features
- Multi-select fields that are populated within the `jira__daily_issue_field_history` and `jira__issue_enhanced` models are automatically joined with `stg_jira__field_option` to ensure the field names are populated. ([#54](https://github.com/fivetran/dbt_jira/pull/54))

# dbt_jira v0.7.0
🎉 dbt v1.0.0 Compatibility 🎉
## 🚨 Breaking Changes 🚨
- Adjusts the `require-dbt-version` to now be within the range [">=1.0.0", "<2.0.0"]. Additionally, the package has been updated for dbt v1.0.0 compatibility. If you are using a dbt version <1.0.0, you will need to upgrade in order to leverage the latest version of the package.
  - For help upgrading your package, I recommend reviewing this GitHub repo's Release Notes on what changes have been implemented since your last upgrade.
  - For help upgrading your dbt project to dbt v1.0.0, I recommend reviewing dbt-labs [upgrading to 1.0.0 docs](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0) for more details on what changes must be made.
- Upgrades the package dependency to refer to the latest `dbt_jira_source`. Additionally, the latest `dbt_jira_source` package has a dependency on the latest `dbt_fivetran_utils`. Further, the latest `dbt_fivetran_utils` package also has a dependency on `dbt_utils` [">=0.8.0", "<0.9.0"].
  - Please note, if you are installing a version of `dbt_utils` in your `packages.yml` that is not in the range above then you will encounter a package dependency error.

# dbt_jira v0.6.0
## 🚨 Breaking Changes 🚨
- This release of the `dbt_jira` packages implements changes to the incremental logic within various models highlighted in the Bug Fixes section below. As such, a `dbt run --full-refresh` will be required after upgrading this dependency for this package in your `packages.yml`.
## Bug Fixes
- Corrected CTE references within `int_jira__issue_assignee_resolution`. The final cte referenced was previously selecting from `issue_field_history` when it should have been selecting from `filtered`. ([#45](https://github.com/fivetran/dbt_jira/pull/45))
- Modified the incremental logic within `int_jira__agg_multiselect_history` to properly capture latest record. Previously, this logic would work for updates made outside of 24 hours. This logic update will now capture any changes since the previous dbt run. ([#48](https://github.com/fivetran/dbt_jira/pull/48))
## Under the Hood
- Modified the `int_jira__issue_calendar_spine` model to use the `dbt-utils.current_timestamp_in_utc` to better capture the current datetime across regions. ([#47](https://github.com/fivetran/dbt_jira/pull/47))

## Contributors
- @thibonacci ([#45](https://github.com/fivetran/dbt_jira/pull/45))

# dbt_jira v0.1.0 -> v0.5.1
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!
