<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_jira/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0_,<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
    <a alt="Fivetran Quickstart Compatible"
        href="https://fivetran.com/docs/transformations/dbt/quickstart">
        <img src="https://img.shields.io/badge/Fivetran_Quickstart_Compatible%3F-yes-green.svg" /></a>
</p>

# Jira Transformation dbt Package ([Docs](https://fivetran.github.io/dbt_jira/))
## What does this dbt package do?
- Produces modeled tables that leverage Jira data from [Fivetran's connector](https://fivetran.com/docs/applications/jira) in the format described by [this ERD](https://fivetran.com/docs/applications/jira#schemainformation) and builds off the output of our [Jira source package](https://github.com/fivetran/dbt_jira_source).
- Enables you to better understand the workload, performance, and velocity of your team's work using Jira issues. It performs the following actions:
  - Creates a daily issue history table so you can quickly create agile reports, such as burndown charts, along any issue field.
  - Enriches the core issue table with relevant data regarding its workflow and current state.
  - Aggregates bandwidth and issue velocity metrics along projects and users.
- Generates a comprehensive data dictionary of your source and modeled Jira data through the [dbt docs site](https://fivetran.github.io/dbt_jira/).

<!--section="jira_transformation_model"-->
The following table provides a detailed list of all tables materialized within this package by default.
> TIP: See more details about these tables in the package's [dbt docs site](https://fivetran.github.io/dbt_jira/#!/overview?g_v=1&g_e=seeds).

| **Table**                | **Description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_field_history](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__daily_issue_field_history)             | Each record represents a day in which an issue remained open, enriched with data about the issue's sprint, its status, and the values of any fields specified by the `issue_field_history_columns` variable. |
| [jira__issue_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__issue_enhanced)            | Each record represents a Jira issue, enriched with data about its current assignee, reporter, sprint, epic, project, resolution, issue type, priority, and status. It also includes metrics reflecting assignments, sprint rollovers, and re-openings of the issue. Note that all epics are considered `issues` in Jira and are therefore included in this model (where `issue_type='epic'`). |
| [jira__project_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__project_enhanced)            | Each record represents a project, enriched with data about the users involved, how many issues have been opened or closed, the velocity of work, and the breadth of the project (i.e., its components and epics). |
| [jira__user_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__user_enhanced)            | Each record represents a user, enriched with metrics regarding their open issues, completed issues, the projects they work on, and the velocity of their work. |
<!--section-end-->

## How do I use the dbt package?

### Step 1: Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran Jira connector syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **Databricks**, or **PostgreSQL** destination.

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

### Step 2: Install the package
Include the following jira package version in your `packages.yml` file:
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.
```yaml
packages:
  - package: fivetran/jira
    version: [">=0.19.0", "<0.20.0"]

```
### Step 3: Define database and schema variables
By default, this package runs using your destination and the `jira` schema. If this is not where your Jira data is (for example, if your Jira schema is named `jira_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    jira_database: your_destination_name
    jira_schema: your_schema_name 
```

### Step 4: Disable models for non-existent sources
Your Jira connector may not sync every table that this package expects. If you do not have the `SPRINT`, `COMPONENT`, or `VERSION` tables synced, add the respective variables to your root `dbt_project.yml` file. Additionally, if you want to remove comment aggregations from your `jira__issue_enhanced` model,  add the `jira_include_comments` variable to your root `dbt_project.yml`:
```yml
vars:
    jira_using_sprints: false    # Enabled by default. Disable if you do not have the sprint table or do not want sprint-related metrics reported.
    jira_using_components: false # Enabled by default. Disable if you do not have the component table or do not want component-related metrics reported.
    jira_using_versions: false   # Enabled by default. Disable if you do not have the versions table or do not want versions-related metrics reported.
    jira_using_priorities: false # Enabled by default. Disable if you are not using priorities in Jira.
    jira_include_comments: false # Enabled by default. Disabling will remove the aggregation of comments via the `count_comments` and `conversations` columns in the `jira__issue_enhanced` table.
```

### (Optional) Step 5: Additional configurations

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
The `jira__daily_issue_field_history` model generates historical data for the columns specified by the `issue_field_history_columns` variable. By default, the only columns tracked are `status`, `status_id`, and `sprint`, but all fields found in the Jira `FIELD` table's `field_name` column can be included in this model. The most recent value of any tracked column is also captured in `jira__issue_enhanced`.

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
    jira_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
    jira:
      +schema: my_new_schema_name # leave blank for just the target_schema
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

### (Optional) Step 6: Orchestrate your models with Fivetran Transformations for dbt Core™
<details><summary>Expand for details</summary>
<br>
    
Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt#setupguide).
</details>

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.
    
```yml
packages:
    - package: fivetran/jira_source
      version: [">=0.7.0", "<0.8.0"]

    - package: fivetran/fivetran_utils
      version: [">=0.4.0", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]

    - package: dbt-labs/spark_utils
      version: [">=0.3.0", "<0.4.0"]
```

## How is this package maintained and can I contribute?
### Package Maintenance
The Fivetran team maintaining this package _only_ maintains the latest version of the package. We highly recommend you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/jira/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_jira/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Check out [this dbt Discourse article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
