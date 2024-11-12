# dbt_jira v0.19.0
[PR #133](https://github.com/fivetran/dbt_jira/pull/133) contains the following updates:

## Breaking Changes
- This change is marked as breaking due to its impact on Redshift configurations.
- For Redshift users, comment data aggregated under the `conversations` field in the `jira__issue_enhanced` table is now disabled by default to prevent consistent errors related to Redshift's varchar length limits. 
  - If you wish to re-enable `conversations` on Redshift, set the `jira_include_conversations` variable to `true` in your `dbt_project.yml`.

## Under the Hood
- Updated the `comment` seed data to ensure conversations are correctly disabled for Redshift by default.
- Renamed the `jira_is_databricks_sql_warehouse` macro to `jira_is_incremental_compatible`, which was updated to return `true` if the Databricks runtime is an all-purpose cluster (previously it checked only for a SQL warehouse runtime) or if the target is any other non-Databricks-supported destination.
  - This update addresses Databricks runtimes (e.g., endpoints and external runtimes) that do not support the `insert_overwrite` incremental strategy used in the `jira__daily_issue_field_history` and `int_jira__pivot_daily_field_history` models.
- For Databricks users, the `jira__daily_issue_field_history` and `int_jira__pivot_daily_field_history` models will now apply the incremental strategy only if running on an all-purpose cluster. All other Databricks runtimes will not utilize an incremental strategy.
- Added consistency tests for the `jira__project_enhanced` and `jira__user_enhanced` models.

# dbt_jira v0.18.0
[PR #131](https://github.com/fivetran/dbt_jira/pull/131) contains the following updates:
## Breaking Changes
> Since the following changes are breaking, a `--full-refresh` after upgrading will be required.

- Changed the partitioning from days to weeks in the following models for BigQuery and Databricks All Purpose Cluster destinations:
  - `int_jira__pivot_daily_field_history`
    - Added field `valid_starting_at_week` for use with the new weekly partition logic.
  - `jira__daily_issue_field_history`
    - Added field `date_week` for use with the new weekly partition logic.
- This adjustment reduces the total number of partitions, helping avoid partition limit issues in certain warehouses.
- For Databricks All Purpose Cluster destinations, updated the `file_format` to `delta` for improved performance.
- Updated the default materialization of `int_jira__issue_calendar_spine` from incremental to ephemeral to improve performance and maintainability.

## Documentation Update
- Updated [README](https://github.com/fivetran/dbt_jira/blob/main/README.md#lookback-window) with the new default of 1 week for the `lookback_window` variable.

## Under the Hood
- Replaced the deprecated `dbt.current_timestamp_backcompat()` function with `dbt.current_timestamp()` to ensure all timestamps are captured in UTC for the following models:
  - `int_jira__issue_calendar_spine`
  - `int_jira__issue_join`
  - `jira__issue_enhanced`
- Updated model `int_jira__issue_calendar_spine` to prevent errors during compilation.
- Added consistency tests for the `jira__daily_issue_field_history` and `jira__issue_enhanced` models.

# dbt_jira v0.17.0
[PR #127](https://github.com/fivetran/dbt_jira/pull/127) contains the following updates:

## 🚨 Breaking Changes 🚨
> ⚠️ Since the following changes are breaking, a `--full-refresh` after upgrading will be required.
- To reduce storage, updated the default materialization of the upstream staging models to views. (See the [dbt_jira_source CHANGELOG](https://github.com/fivetran/dbt_jira_source/blob/main/CHANGELOG.md#dbt_jira_source-v070) for more details.)

## Performance improvements (🚨 Breaking Changes 🚨)
  - Updated the incremental strategy of the following models to `insert_overwrite` for BigQuery and Databricks All Purpose Cluster destinations and `delete+insert` for all other supported destinations. 
    - `int_jira__issue_calendar_spine`
    - `int_jira__pivot_daily_field_history`
    - `jira__daily_issue_field_history`
    > At this time, models for Databricks SQL Warehouse destinations are materialized as tables without support for incremental runs.

  - Removed intermediate models `int_jira__agg_multiselect_history`, `int_jira__combine_field_histories`, and `int_jira__daily_field_history` by combining them with `int_jira__pivot_daily_field_history`. This is to reduce the redundancy of the data stored in tables, the number of full scans, and the volume of write operations.
    - Note that if you have previously run this package, these models may still exist in your destination schema, however they will no longer be updated. 
  - Updated the default materialization of `int_jira__issue_type_parents` from a table to a view. This model is called only in `int_jira__issue_users`, so a view will reduce storage requirements while not significantly hindering performance.
  - For Snowflake and BigQuery destinations, added the following `cluster_by` columns to the configs for incremental models:
    - `int_jira__issue_calendar_spine` clustering on columns `['date_day', 'issue_id']`
    - `int_jira__pivot_daily_field_history` clustering on columns `['valid_starting_on', 'issue_id']`
    - `jira__daily_issue_field_history` clustering on columns `['date_day', 'issue_id']`
  - For Databricks All Purpose Cluster destinations, updated incremental model file formats to `parquet` for compatibility with the `insert_overwrite` strategy.

## Features
- Added a default 3-day look-back to incremental models to accommodate late arriving records. The number of days can be changed by setting the var `lookback_window` in your dbt_project.yml. See the [Lookback Window section of the README](https://github.com/fivetran/dbt_jira/blob/main/README.md#lookback-window) for more details.
- Added macro `jira_lookback` to streamline the lookback window calculation.

## Under the Hood:
- Added integration testing pipeline for Databricks SQL Warehouse.
- Added macro `jira_is_databricks_sql_warehouse` for detecting if a Databricks target is an All Purpose Cluster or a SQL Warehouse.
- Updated the maintainer pull request template.

# dbt_jira v0.16.0
[PR #122](https://github.com/fivetran/dbt_jira/pull/122) contains the following updates:

## 🚨 Breaking Changes: Bug Fixes 🚨
- The following fields in the below mentioned models have been converted to a string datatype (previously integer) to ensure classic Jira projects may link issues to epics. In classic Jira projects the epic reference is in a hyperlink form (ie. "https://ulr-here/epic-key") as opposed to an ID. As such, a string datatype is needed to successfully link issues to epics. If you are referencing these fields downstream, be sure to make any changes to account for the new datatype.
  - `revised_parent_issue_id` field within the `int_jira__issue_type_parents` model
  - `parent_issue_id` field within the `jira__issue_enhanced` model

## Documentation updates
- Update README to highlight requirements for using custom fields with the `issue_field_history_columns` variable.

## Under the Hood
- Included auto-releaser GitHub Actions workflow to automate future releases.
- Updated the maintainer PR template to resemble the most up to date format.
- Updated `field` and `issue_field_history` seed files to ensure we have an updated test case to capture the epic-link scenario for classic Jira environments.

# dbt_jira v0.15.0
[PR #108](https://github.com/fivetran/dbt_jira/pull/108) contains the following updates:
## 🚨 Breaking Changes 🚨
- Updated the `jira__daily_issue_field_history` model to make sure `issue_type` values are correctly joined into the downstream issue models. This applied only if `issue type` is leveraged within the `issue_field_history_columns` variable.
>**Note**: Please be aware that a `dbt run --full-refresh` will be required after upgrading to this version in order to capture the updates.

# dbt_jira v0.14.0 
## 🚨 Breaking Changes 🚨
- Fixed the `jira__daily_issue_field_history` model to make sure `component` values are correctly joined into the downstream issue models. This applied only if `components` are leveraged within the `issue_field_history_columns` variable. ([PR #99](https://github.com/fivetran/dbt_jira/pull/99))
>**Note**: Please be aware that a `dbt run --full-refresh` will be required after upgrading to this version in order to capture the updates.

## Bug Fixes
- Updated the `int_jira__issue_calendar_spine` logic, which now references the `int_jira__field_history_scd` model as an upstream dependency. ([PR #104](https://github.com/fivetran/dbt_jira/pull/104))
- Modified the `open_until` field  within the `int_jira__issue_calendar_spine` model to be dependent on the `int_jira__field_history_scd` model's `valid_starting_on` column as opposed to the `issue` table's `updated_at` field. ([PR #104](https://github.com/fivetran/dbt_jira/pull/104))
  - This is required as some resolved issues (outside of the 30 day or `jira_issue_history_buffer` variable window) were having faulty incremental loads due to untracked fields (fields not tracked via the `issue_field_history_columns` variable or other fields not identified in the history tables such as Links, Comments, etc.). This caused the `updated_at` column to update, but there were no tracked fields that were updated, thus causing a faulty incremental load.


## Under the Hood
- Added additional seed rows to ensure the new configuration for components properly runs for all edge cases and compare against normal issue field history fields like `summary`. ([PR #104](https://github.com/fivetran/dbt_jira/pull/104))
- Incorporated the new `fivetran_utils.drop_schemas_automation` macro into the end of each Buildkite integration test job. ([PR #98](https://github.com/fivetran/dbt_jira/pull/98))
- Updated the pull request templates. ([PR #98](https://github.com/fivetran/dbt_jira/pull/98))
 
## Contributors
- [@kenzie-marsh](https://github.com/kenzie-marsh) ([Issue #100](https://github.com/fivetran/dbt_jira/issues/100))


# dbt_jira v0.13.0
## 🚨 Breaking Changes 🚨:
[PR #95](https://github.com/fivetran/dbt_jira/pull/95) applies the following changes:
- Added the `status_id` column as a default field for the `jira__daily_issue_field_history` model. This is required to perform an accurate join for the `status` field in incremental runs.
  - Please be aware a `dbt run --full-refresh` will be required following this upgrade.

## 🎉 Feature Updates 🎉
[PR #93](https://github.com/fivetran/dbt_jira/pull/93) applies the following changes:
- Adds the option to use `field_name` instead of `field_id` as the field-grain for issue field history transformations. Previously, the package would strictly partition and join issue field data using `field_id`. However, this assumed that it was impossible to have fields with the same name in Jira. For instance, it is very easy to create another `Sprint` field, and different Jira users across your organization may choose the wrong or inconsistent version of the field. 
  - Thus, to treat these as the same field, set the new `jira_field_grain` variable to `'field_name'` in your `dbt_project.yml` file. You must run a full refresh to accurately fold this change in.

## Under the Hood
[PR #95](https://github.com/fivetran/dbt_jira/pull/95) applies the following changes:
- With the addition of the default `status_id` field in the `jira__daily_issue_field_history` model, there is no longer a need to do the extra partitioning to fill values for the `status` field. As such, the `status` partitions were removed in place of `status_id`. However, in the final cte of the model we join in the status staging model to populate the appropriate status per the accurate status_id for the given day.

## Contributors
- [@RivkiHofman](https://github.com/RivkiHofman) ([#92](https://github.com/fivetran/dbt_jira/pull/92))

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
