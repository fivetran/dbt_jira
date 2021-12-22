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
