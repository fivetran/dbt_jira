<!--section="jira_transformation_model"-->
# Jira dbt Package

<p align="left">
    <a alt="License"
        href="https://github.com/fivetran/dbt_jira/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0,_<3.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
    <a alt="Fivetran Quickstart Compatible"
        href="https://fivetran.com/docs/transformations/data-models/quickstart-management#quickstartmanagement">
        <img src="https://img.shields.io/badge/Fivetran_Quickstart_Compatible%3F-yes-green.svg" /></a>
</p>

This dbt package transforms data from Fivetran's Jira connector into analytics-ready tables.

## Resources

- Number of materialized models¹: 48
- Connector documentation
  - [Jira connector documentation](https://fivetran.com/docs/connectors/applications/jira)
  - [Jira ERD](https://fivetran.com/docs/connectors/applications/jira#schemainformation)
- dbt package documentation
  - [GitHub repository](https://github.com/fivetran/dbt_jira)
  - [dbt Docs](https://fivetran.github.io/dbt_jira/#!/overview)
  - [DAG](https://fivetran.github.io/dbt_jira/#!/overview?g_v=1)
  - [Changelog](https://github.com/fivetran/dbt_jira/blob/main/CHANGELOG.md)

## What does this dbt package do?
This package enables you to better understand the workload, performance, and velocity of your team's work using Jira issues. It creates enriched models with metrics focused on daily issue history, workflow analysis, and team performance.

### Output schema
Final output tables are generated in the following target schema:

```
<your_database>.<connector/schema_name>_jira
```

### Final output tables

By default, this package materializes the following final tables:

| Table | Description |
| :---- | :---- |
| [jira__daily_issue_field_history](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__daily_issue_field_history) | History table with one row for each day an issue remained open, with additional details about the issue sprint, status, and story points (if enabled). For an example of how this data can be used, see [this analysis query](https://fivetran.github.io/dbt_jira/#!/analysis/analysis.jira.jira__daily_issue_status_category_analysis), which demonstrates how you might build a daily issue status category analysis on top of this table. <br><br>**Example Analytics Questions:**<br><ul><li>How many issues, by sprint, were Closed or Blocked each week in Q1, 2025?</li><li>How many days, on average, does it take an issue to go from 'Accepted' to either 'Closed' or 'Blocked'?</li></ul> |
| [jira__timestamp_issue_field_history](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__timestamp_issue_field_history) | Table tracking field changes at timestamp level with validity periods. Each record shows complete field state during a time period with `valid_from`/`valid_until` timestamps. For an example of how this data can be used, see [this analysis query](https://fivetran.github.io/dbt_jira/#!/analysis/analysis.jira.jira__issue_transition_cumulative_flow_analysis), which demonstrates building an issue transition cumulative flow analysis. <br><br>**Example Analytics Questions:**<br><ul><li>What was the exact sequence of field changes for a specific issue?</li><li>How long did an issue spend in each status with precise timing?</li></ul> |
| [jira__issue_status_transitions](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__issue_status_transitions) | Issue status transition tracking with workflow analysis. Provides chronological view of status changes with timing metrics, transition direction analysis, and lifecycle indicators. <br><br>**Example Analytics Questions:**<br><ul><li>What is the average time spent in each status across all issues?</li><li>Which is the lead time and cycle time for issues based on when work is added/started/completed?</li><li>What are the most common workflow transition paths?</li></ul> |
| [jira__issue_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__issue_enhanced) | One row per Jira issue with enriched details about assignee, reporter, sprint, project, and current status, plus metrics on assignments and re-openings. <br><br>**Example Analytics Questions:**<br><ul><li>How many issues are currently blocked and who owns them?</li><li>What's the average time to resolution for high-priority bugs by assignee?</li></ul> |
| [jira__project_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__project_enhanced) | One row per project with team member details, issue counts, work velocity metrics, and project scope information. <br><br>**Example Analytics Questions:**<br><ul><li>Which projects have the highest velocity in terms of issues closed per sprint?</li><li>What is the ratio of unassigned open tickets to assigned open tickets by project?</li></ul> |
| [jira__user_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__user_enhanced) | One row per user with metrics on open and completed issues, and individual work velocity. <br><br>**Example Analytics Questions:**<br><ul><li>Who are the top performers in terms of issues resolved per month?</li><li>Which team members have the highest workload based on open issue count and how long, on average, have those issues been open?</li></ul> |
| [jira__sprint_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__sprint_enhanced) | One row per sprint with metrics on issues created, resolved, and carried over, plus story point estimates. <br><br>**Example Analytics Questions:**<br><ul><li>Which sprints had the highest velocity and what made them successful?</li><li>How many story points were planned vs. completed across recent sprints?</li><li>What percentage of issues are typically carried over from sprint to sprint?</li></ul> |
| [jira__daily_sprint_issue_history](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__daily_sprint_issue_history) | Daily snapshot of each sprint showing all associated issues from sprint start to end, useful for tracking progress over time. <br><br>**Example Analytics Questions:**<br><ul><li>How many issues were active in each sprint on any given day?</li><li>What's the daily count of open vs. completed issues per sprint?</li><li>Which sprints had issues added or removed mid-sprint?</li></ul> |

¹ Each Quickstart transformation job run materializes these models if all components of this data model are enabled. This count includes all staging, intermediate, and final models materialized as `view`, `table`, or `incremental`.

---

## Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran Jira connection syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **Databricks**, or **PostgreSQL** destination.

## How do I use the dbt package?
You can either add this dbt package in the Fivetran dashboard or import it into your dbt project:

- To add the package in the Fivetran dashboard, follow our [Quickstart guide](https://fivetran.com/docs/transformations/data-models/quickstart-management).
- To add the package to your dbt project, follow the setup instructions in the dbt package's [README file](https://github.com/fivetran/dbt_jira/blob/main/README.md#how-do-i-use-the-dbt-package) to use this package.

<!--section-end-->

### Install the package
Include the following jira package version in your `packages.yml` file:
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.
```yaml
packages:
  - package: fivetran/jira
    version: [">=1.5.0", "<1.6.0"]
```

> All required sources and staging models are now bundled into this transformation package. Do not include `fivetran/jira_source` in your `packages.yml` since this package has been deprecated.

#### Databricks Dispatch Configuration
If you are using a Databricks destination with this package you will need to add the below (or a variation of the below) dispatch configuration within your `dbt_project.yml`. This is required in order for the package to accurately search for macros within the `dbt-labs/spark_utils` then the `dbt-labs/dbt_utils` packages respectively.
```yml
dispatch:
  - macro_namespace: dbt_utils
    search_order: ['spark_utils', 'dbt_utils']
```

#### Database Incremental Strategies
Models in this package that are materialized incrementally are configured to work with the different strategies available to each supported warehouse.

For **BigQuery** and **Databricks All Purpose Cluster runtime** destinations, we have chosen `insert_overwrite` as the default strategy, which benefits from the partitioning capability.
> For Databricks SQL Warehouse destinations, models are materialized as tables without support for incremental runs.

For **Snowflake**, **Redshift**, and **Postgres** databases, we have chosen `delete+insert` as the default strategy.

> Regardless of strategy, we recommend that users periodically run a `--full-refresh` to ensure a high level of data quality.

### Define database and schema variables

#### Option A: Single connection
By default, this package runs using your destination and the `jira` schema. If this is not where your Jira data is (for example, if your Jira schema is named `jira_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    jira_database: your_destination_name
    jira_schema: your_schema_name
```

#### Option B: Union multiple connections
If you have multiple Jira connections in Fivetran and would like to use this package on all of them simultaneously, we have provided functionality to do so. For each source table, the package will union all of the data together and pass the unioned table into the transformations. The `source_relation` column in each model indicates the origin of each record.

To use this functionality, you will need to set the `jira_sources` variable in your root `dbt_project.yml` file:

```yml
# dbt_project.yml

vars:
  jira:
    jira_sources:
      - database: connection_1_destination_name # Required
        schema: connection_1_schema_name # Required
        name: connection_1_source_name # Required only if following the step in the following subsection

      - database: connection_2_destination_name
        schema: connection_2_schema_name
        name: connection_2_source_name
```

##### Recommended: Incorporate unioned sources into DAG
> *If you are running the package through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt#transformationsfordbtcore), the below step is necessary in order to synchronize model runs with your Jira connections. Alternatively, you may choose to run the package through Fivetran [Quickstart](https://fivetran.com/docs/transformations/quickstart), which would create separate sets of models for each Jira source rather than one set of unioned models.*

By default, this package defines one single-connection source, called `jira`, which will be disabled if you are unioning multiple connections. This means that your DAG will not include your Jira sources, though the package will run successfully.

To properly incorporate all of your Jira connections into your project's DAG:
1. Define each of your sources in a `.yml` file in your project. Utilize the following template for the `source`-level configurations, and, **most importantly**, copy and paste the table and column-level definitions from the package's `src_jira.yml` [file](https://github.com/fivetran/dbt_jira/blob/main/models/staging/src_jira.yml).

```yml
# a .yml file in your root project

version: 2

sources:
  - name: <name> # ex: Should match name in jira_sources
    schema: <schema_name>
    database: <database_name>
    loader: fivetran
    config:
      loaded_at_field: _fivetran_synced
      freshness: # feel free to adjust to your liking
        warn_after: {count: 72, period: hour}
        error_after: {count: 168, period: hour}

    tables: # copy and paste from jira/models/staging/src_jira.yml - see https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors/ for how to use anchors to only do so once
```

> **Note**: If there are source tables you do not have (see [Disable models for non existent sources](https://github.com/fivetran/dbt_jira?tab=readme-ov-file#disable-models-for-non-existent-sources)), you may still include them, as long as you have set the right variables to `False`.

2. Set the `has_defined_sources` variable (scoped to the `jira` package) to `True`, like such:
```yml
# dbt_project.yml
vars:
  jira:
    has_defined_sources: true
```

### Disable models for non-existent sources
Your Jira connection may not sync every table that this package expects. If you do not have the `SPRINT`, `COMPONENT`, `VERSION`, `PRIORITY` or `TEAM` tables synced, add the respective variables to your root `dbt_project.yml` file. Additionally, if you want to remove comment aggregations from your `jira__issue_enhanced` model,  add the `jira_include_comments` variable to your root `dbt_project.yml`:
```yml
vars:
    jira_using_sprints: false    # Enabled by default. Disable if you do not have the sprint table or do not want sprint-related metrics reported.
    jira_using_components: false # Enabled by default. Disable if you do not have the component table or do not want component-related metrics reported.
    jira_using_versions: false   # Enabled by default. Disable if you do not have the versions table or do not want versions-related metrics reported.
    jira_using_priorities: false # Enabled by default. Disable if you are not using priorities in Jira.
    jira_using_teams: false # Enabled by default. Disable if you are not using teams in Jira.
    jira_include_comments: false # Enabled by default. Disabling will remove the aggregation of comments via the `count_comments` and `conversations` columns in the `jira__issue_enhanced` table.
```

### (Optional) Additional configurations

#### Controlling conversation aggregations in `jira__issue_enhanced`

The `dbt_jira` package offers variables to enable or disable conversation aggregations in the `jira__issue_enhanced` table. These settings allow you to manage the amount of data processed and avoid potential performance or limit issues with large datasets.

- `jira_include_conversations`: Controls only the `conversation` [column](https://github.com/fivetran/dbt_jira/blob/main/models/jira.yml#L125-L127) in the `jira__issue_enhanced` table. 
  - Default: Disabled for Redshift due to string size constraints; enabled for other supported warehouses.
  - Setting this to `false` removes the `conversation` column but retains the `count_comments` field if `jira_include_comments` is still enabled. This is useful if you want a comment count without the full conversation details.

In your `dbt_project.yml` file:

```yml
vars:
  jira_include_conversations: false/true # Disabled by default for Redshift; enabled for other supported warehouses.
```

#### Define daily issue field history columns
The `jira__daily_issue_field_history` and `jira__timestamp_issue_field_history` models generate historical data for the columns specified by the `issue_field_history_columns` variable. By default, the columns tracked in `jira__daily_issue_field_history` are `status`, `status_id`, `sprint`, `story_points` and `story_point_estimate`; and in `jira__timestamp_issue_field_history`, it's `status`, `status_id` and `sprint`. But all fields found in the Jira `FIELD` table's `field_name` column can be included in these models. The most recent value of any tracked column is also captured in `jira__issue_enhanced`.

If you would like to change these columns, add the following configuration to your `dbt_project.yml` file. After adding the columns to your `dbt_project.yml` file, run the `dbt run --full-refresh` command to fully refresh any existing models:

> IMPORTANT: If you wish to use a custom field, be sure to list the `field_name` and not the `field_id`. The corresponding `field_name` can be found in the `stg_jira__field` model.

```yml
vars:
    issue_field_history_columns: ['the', 'list', 'of', 'field', 'names']
```

#### Adjust the field-grain for issue field history transformations if duplicate field names
This package provides the option to use `field_name` instead of `field_id` as the field-grain for issue field history transformations. By default, the package strictly partitions and joins issue field data using `field_id`. However, this assumes that it is impossible to have fields with the same name in Jira. For instance, it is very easy to create another `Sprint` field, and different Jira users across your organization may choose the wrong or inconsistent version of the field. As such, the `jira_field_grain` variable may be adjusted to change the field-grain behavior of the issue field history  models. You may adjust the variable using the following configuration in your root dbt_project.yml.

```yml
vars:
    jira_field_grain: 'field_name' # field_id by default
```

#### Extend the history of an issue past its closing date
This packages allows you the option to utilize a buffer variable to bring in issues past their date of close. This is because issues can be left unresolved past that date. This buffer variable ensures that this daily issue history will not cut off field updates to these particular issues.

You may adjust the variable using the following configuration in your root `dbt_project.yml`.

```yml
vars:
    jira_issue_history_buffer: insert_number_of_months # 1 by default
```

#### Change the build schema
By default, this package builds the Jira staging models within a schema titled (`<target_schema>` + `_jira_source`) and your Jira modeling models within a schema titled (`<target_schema>` + `_jira`) in your destination. If this is not where you would like your Jira data to be written to, add the following configuration to your root `dbt_project.yml` file:

```yml
models:
    jira:
      +schema: my_new_schema_name # Leave +schema: blank to use the default target_schema.
      staging:
        +schema: my_new_schema_name # Leave +schema: blank to use the default target_schema.
```

#### Change the source table references
If an individual source table has a different name than the package expects, add the table name as it appears in your destination to the respective variable:

> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_jira/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    jira_<default_source_table_name>_identifier: your_table_name 
```

#### Lookback Window
Records from the source may occasionally arrive late. To handle this, we implement a one-week lookback in our incremental models to capture late arrivals without requiring frequent full refreshes. The lookback is structured in weekly increments, as the incremental logic is based on weekly periods. While the frequency of full refreshes can be reduced, we still recommend running `dbt --full-refresh` periodically to maintain data quality of the models. 

To change the default lookback window, add the following variable to your `dbt_project.yml` file:

```yml
vars:
  jira:
    lookback_window: number_of_weeks # default is 1
```

### (Optional) Orchestrate your models with Fivetran Transformations for dbt Core™
<details><summary>Expand for details</summary>
<br>

Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt#transformationsfordbtcore). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt/setup-guide#transformationsfordbtcoresetupguide).
</details>

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.

```yml
packages:
    - package: fivetran/fivetran_utils
      version: [">=0.4.0", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]

    - package: dbt-labs/spark_utils
      version: [">=0.3.0", "<0.4.0"]
```

<!--section="jira_maintenance"-->
## How is this package maintained and can I contribute?

### Package Maintenance
The Fivetran team maintaining this package only maintains the [latest version](https://hub.getdbt.com/fivetran/jira/latest/) of the package. We highly recommend you stay consistent with the latest version of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_jira/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Learn how to contribute to a package in dbt's [Contributing to an external dbt package article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657).

<!--section-end-->

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
