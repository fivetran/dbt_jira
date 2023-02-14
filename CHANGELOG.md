# dbt_jira v0.12.2
## Bug Fixes
- Reverting the changes introduced between v0.12.1 except Databricks compatibility. Please stay tuned for a future release that will integrate the v0.12.1 changes in a bug free release. ([#88](https://github.com/fivetran/dbt_jira/pull/88))
# dbt_jira v0.12.1
## 🚨 Breaking Changes 🚨:
- Fixed `jira__daily_issue_field_history` model to make sure component values are correctly joined into our issue models ([#81](https://github.com/fivetran/dbt_jira/pull/81)).
- Please note, a `dbt run --full-refresh` will be required after upgrading to this version in order to capture the updates.
## 🎉 Feature Updates 🎉
- Databricks compatibility 🧱 ([#80](https://github.com/fivetran/dbt_jira/pull/80)).

# dbt_jira v0.11.0
## 🚨 Breaking Changes 🚨:
[PR #74](https://github.com/fivetran/dbt_jira/pull/74) includes the following breaking changes:
- Dispatch update for dbt-utils to dbt-core cross-db macros migration. Specifically `{{ dbt_utils.<macro> }}` have been updated to `{{ dbt.<macro> }}` for the below macros:
    - `any_value`
    - `bool_or`
    - `cast_bool_to_text`
    - `concat`
    - `date_trunc`
    - `dateadd`
    - `datediff`
    - `escape_single_quotes`
    - `except`
    - `hash`
    - `intersect`
    - `last_day`
    - `length`
    - `listagg`
    - `position`
    - `replace`
    - `right`
    - `safe_cast`
    - `split_part`
    - `string_literal`
    - `type_bigint`
    - `type_float`
    - `type_int`
    - `type_numeric`
    - `type_string`
    - `type_timestamp`
    - `array_append`
    - `array_concat`
    - `array_construct`
- For `current_timestamp` and `current_timestamp_in_utc` macros, the dispatch AND the macro names have been updated to the below, respectively:
    - `dbt.current_timestamp_backcompat`
    - `dbt.current_timestamp_in_utc_backcompat`
- `dbt_utils.surrogate_key` has also been updated to `dbt_utils.generate_surrogate_key`. Since the method for creating surrogate keys differ, we suggest all users do a `full-refresh` for the most accurate data. For more information, please refer to dbt-utils [release notes](https://github.com/dbt-labs/dbt-utils/releases) for this update.
- Dependencies on `fivetran/fivetran_utils` have been upgraded, previously `[">=0.3.0", "<0.4.0"]` now `[">=0.4.0", "<0.5.0"]`.
- Incremental strategies for all incremental models in this package have been adjusted to use `delete+insert` if the warehouse being used is Snowflake, Postgres, or Redshift.

# dbt_jira v0.10.1
## ❗Please Note❗
- While this is a patch update, it may also require a full refresh. Please run `dbt run --full-refresh` after upgrading to ensure you have the latest incremental logic.
## 🐞 Bug Fix
- Updated logic for model `int_jira__issue_sprint` to further adjust how current sprint is determined. It now uses a combination of the newest `updated_at` date for the issue and the newest `started_at` date of the sprint. This is to account for times when jira updates two sprint records at the same time. ([#77](https://github.com/fivetran/dbt_jira/pull/77) and [#78](https://github.com/fivetran/dbt_jira/pull/78))
## Contributors
- [@jingyu-spenmo](https://github.com/jingyu-spenmo) ([#78](https://github.com/fivetran/dbt_jira/pull/78))


# dbt_jira v0.10.0
## 🚨 Breaking Changes
- For model `jira__issue_enhanced`, updated column names `sprint_id` and `sprint_name` to `current_sprint_id` and `current_sprint_name`, respectively, to confirm the record is for the current sprint. ([#76](https://github.com/fivetran/dbt_jira/pull/76))

## 🐞 Bug Fix
- Updated logic for model `int_jira__issue_sprint` to adjust how current sprint is determined. It now uses the newest `started_at` date of the sprint instead of the `updated_at` date. ([#76](https://github.com/fivetran/dbt_jira/pull/76))

# dbt_jira v0.9.0
## 🚨 Breaking Changes 🚨

- The default schema for the source tables are now built within a schema titled (`<target_schema>` + `_jira_source`) in your destination. The previous default schema was (`<target_schema>` + `_stg_jira`) for source. This may be overwritten if desired. ([#63](https://github.com/fivetran/dbt_jira/pull/63))
- Flipped column aliases `sum_close_time_seconds` and `sum_current_open_seconds` of intermediate model `int_jira__user_metrics.sql`. ([#66](https://github.com/fivetran/dbt_jira/pull/66))
- This ensures that downstream model `jira__user_enhanced.sql` calculates columns `avg_age_currently_open_seconds` and `avg_close_time_seconds` correctly. ([#66](https://github.com/fivetran/dbt_jira/pull/66))

## 🎉 Documentation and Feature Updates
- Updated README documentation updates for easier navigation and setup of the dbt package. ([#63](https://github.com/fivetran/dbt_jira/pull/63))
- Added `jira_[source_table_name]_identifier` variables to allow for easier flexibility of the package to refer to source tables with different names. ([#63](https://github.com/fivetran/dbt_jira/pull/63))

## Bug Fixes
- Corrected bug introduced in 0.8.0 that would prevent the correct `status` data from being passed to model `jira__daily_issue_field_history`. ([#63](https://github.com/fivetran/dbt_jira/pull/63))
  - Please note, a `dbt run --full-refresh` will be required after upgrading to this version in order to capture the updates.

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
