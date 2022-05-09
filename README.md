<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_jira/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="Fivetran-Release"
        href="https://fivetran.com/docs/getting-started/core-concepts#releasephases">
        <img src="https://img.shields.io/badge/Fivetran Release Phase-_Beta-orange.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.0.0_,<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
</p>

# Jira Modeling dbt Package ([Docs](https://fivetran.github.io/dbt_jira/))
# 📣 What does this dbt package do?
- Produces modeled tables that leverage Jira data from [Fivetran's connector](https://fivetran.com/docs/applications/jira) in the format described by [this ERD](https://docs.google.com/presentation/d/10lOpfJxsFWWP5OQKcYb-QX9YlQJvOcT4XyIDI_o7Vm0/edit) and builds off the output of our [Jira source package](https://github.com/fivetran/dbt_jira_source).
- The above mentioned models enable you to better understand the workload, performance, and velocity of work done by your team using Jira issues. It achieves this by:
  - Creating a daily issue history table to enable the quick creation of agile reports, such as burndown charts, along any issue field
  - Enrich the core issue table with relevant data regarding its workflow and current state
  - Aggregating bandwidth and issue velocity metrics along projects and users
- Generates a comprehensive data dictionary of your source and modeled Jira data via the [dbt docs site](https://fivetran.github.io/dbt_jira/)

Refer to the table below for a detailed view of all models materialized by default within this package. Additionally, check out our [docs site](https://fivetran.github.io/dbt_jira/#!/overview?g_v=1) for more details about these models. 
| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_field_history](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__daily_issue_field_history)             | Each record represents a day in which an issue remained open, complete with the issue's sprint, its status, and the values of any fields specified by the `issue_field_history_columns` variable. |
| [jira__issue_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__issue_enhanced)            | Each record represents a Jira issue, enriched with data about its current assignee, reporter, sprint, epic, project, resolution, issue type, priority, and status. Also includes metrics reflecting assignments, sprint rollovers, and re-openings of the issue. Note: all epics are considered `issues` in Jira, and are therefore included in this model (where `issue_type='epic'`). |
| [jira__project_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__project_enhanced)            | Each record represents a project, enriched with data about the users involved, how many issues have been opened or closed, the velocity of work, and the breadth of the project (ie its components and epics). |
| [jira__user_enhanced](https://fivetran.github.io/dbt_jira/#!/model/model.jira.jira__user_enhanced)            | Each record represents a user, enriched with metrics regarding their open issues, completed issues, the projects they work on, and the velocity of their work. |
# 🤔 Who is the target user of this dbt package?
- You use Fivetran's [Jira connector](https://fivetran.com/docs/applications/Jira)
- You use dbt
- You want a staging layer that cleans, tests, and prepares your Jira data for analysis as well as leverage the analysis ready models outlined above.
# 🎯 How do I use the dbt package?
To effectively install this package and leverage the pre-made models, you will follow the below steps:
## Step 1: Pre-Requisites
You will need to ensure you have the following before leveraging the dbt package.
- **Connector**: Have the Fivetran Jira connector syncing data into your warehouse. 
- **Database support**: This package has been tested on **BigQuery**, **Snowflake**, **Redshift**, and **Postgres**. Ensure you are using one of these supported databases.
- **dbt Version**: This dbt package requires you have a functional dbt project that utilizes a dbt version within the respective range `>=1.0.0, <2.0.0`.
## Step 2: Installing the Package
Include the following jira_source package version in your `packages.yml`
> Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.
```yaml
packages:
  - package: fivetran/jira
    version: [">=0.9.0", "<0.10.0"]

```
## Step 3: Configure Your Variables
### Database and Schema Variables
By default, this package will run using your target database and the `jira` schema. If this is not where your Jira data is (perhaps your Jira schema is `jira_fivetran` and your `issue` table is named `usa_issue`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    jira_database: your_database_name
    jira_schema: your_schema_name 
    jira__<default_source_table_name>_identifier: your_table_name
```

### Disabling Components
Your Jira connector might not sync every table that this package expects. If you do not have the `SPRINT`, `COMPONENT`, or `VERSION` tables synced, add the respective variables to your root `dbt_project.yml` file. Additionally, if you wish to remove comment aggregations from your `jira__issue_enhanced` model, then add the `jira_include_comments` variable to your root `dbt_project.yml`:
```yml
vars:
    jira_using_sprints: false   # Disable if you do not have the sprint table, or if you do not want sprint related metrics reported
    jira_using_components: false # Disable if you do not have the component table, or if you do not want component related metrics reported
    jira_using_versions: false # Disable if you do not have the versions table, or if you do not want versions related metrics reported
    jira_include_comments: false # this package aggregates issue comments so that you have a single view of all your comments in the jira__issue_enhanced table. This can cause limit errors if you have a large dataset. Disable to remove this functionality.
```
### Daily Issue Field History Columns
The `jira__daily_issue_field_history` model generates historical data for the columns specified by the `issue_field_history_columns` variable. By default, the only columns tracked are `status` and `sprint`, but all fields found in the `field_name` column within the Jira `FIELD` table can be included in this model. The most recent value of any tracked column is also captured in `jira__issue_enhanced`.
**If you would like to change these columns, add the following configuration to your dbt_project.yml file. Then, after adding the columns to your `dbt_project.yml` file, run the `dbt run --full-refresh` command to fully refresh any existing models.**

```yml
vars:
    issue_field_history_columns: ['the', 'list', 'of', 'field', 'names']
```

## (Optional) Step 4: Additional Configurations
### Change the Build Schema
By default, this package builds the Jira staging models within a schema titled (<target_schema> + _stg_jira) and your Jira modeling models within a schema titled (<target_schema> + _jira) in your target database. If this is not where you would like your Jira data to be written to, add the following configuration to your root `dbt_project.yml` file:

```yml
models:
    jira_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
    jira:
      +schema: my_new_schema_name # leave blank for just the target_schema
```

## Step 5: Finish Setup
Your dbt project is now setup to successfully run the dbt package models! You can now execute `dbt run` and `dbt test` to have the models materialize in your warehouse and execute the data integrity tests applied within the package.

## (Optional) Step 6: Orchestrate your package models with Fivetran
Fivetran offers the ability for you to orchestrate your dbt project through the [Fivetran Transformations for dbt Core](https://fivetran.com/docs/transformations/dbt) product. Refer to the linked docs for more information on how to setup your project for orchestration through Fivetran. 

# 🔍 Does this package have dependencies?
This dbt package is dependent on the following dbt packages. For more information on the below packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> **If you have any of these dependent packages in your own `packages.yml` I highly recommend you remove them to ensure there are no package version conflicts.**
```yml
packages:
    - package: fivetran/jira_source
      version: [">=0.5.0", "<0.6.0"]

    - package: fivetran/fivetran_utils
      version: [">=0.3.0", "<0.4.0"]

    - package: dbt-labs/dbt_utils
      version: [">=0.8.0", "<0.9.0"]
```
# 🙌 How is this package maintained and can I contribute?
## Package Maintenance
The Fivetran team maintaining this package **only** maintains the latest version of the package. We highly recommend you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/jira/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_jira/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

## Contributions
These dbt packages are developed by a small team of analytics engineers at Fivetran. However, the packages are made better by community contributions! 

We highly encourage and welcome contributions to this package. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package!

# 🏪 Are there any resources available?
- If you encounter any questions or want to reach out for help, please refer to the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran, or would like to request a future dbt package to be developed, then feel free to fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
- Have questions or want to just say hi? Book a time during our office hours [here](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or send us an email at solutions@fivetran.com.
