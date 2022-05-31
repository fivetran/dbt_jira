[![Apache License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
# Jira

This package models Jira data from [Fivetran's connector](https://fivetran.com/docs/applications/jira). It uses data in the format described by [this ERD](https://fivetran.com/docs/applications/jira/#schemainformation).

This package enables you to better understand the workload, performance, and velocity of work done by your team using Jira issues. It achieves this by:
- Creating a daily issue history table to enable the quick creation of agile reports, such as burndown charts, along any issue field
- Enriching the core issue table with relevant data regarding its workflow and current state
- Aggregating bandwidth and issue velocity metrics along projects and users

## Compatibility
> Please be aware the [dbt_jira](https://github.com/fivetran/dbt_jira) and [dbt_jira_source](https://github.com/fivetran/dbt_jira_source) packages will only work with the [Fivetran Jira schema](https://fivetran.com/docs/applications/jira/changelog) released after September 10, 2020. If your Jira connector was set up prior to September 10, 2020, you will need to fully resync or set up a new Jira connector in order for the Fivetran dbt Jira packages to work.

## Models

This package contains transformation models, designed to work simultaneously with our [Jira source package](https://github.com/fivetran/dbt_jira_source). A dependency on the source package is declared in this package's `packages.yml` file, so it will automatically download when you run `dbt deps`. The primary outputs of this package are described below. Intermediate models are used to create these output models.

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_field_history](https://github.com/fivetran/dbt_jira/blob/master/models/jira__daily_issue_field_history.sql)             | Each record represents a day in which an issue remained open, complete with the issue's sprint, its status, and the values of any fields specified by the `issue_field_history_columns` variable. |
| [jira__issue_enhanced](https://github.com/fivetran/dbt_jira/blob/master/models/jira__issue_enhanced.sql)            | Each record represents a Jira issue, enriched with data about its current assignee, reporter, sprint, epic, project, resolution, issue type, priority, and status. Also includes metrics reflecting assignments, sprint rollovers, and re-openings of the issue. Note: all epics are considered `issues` in Jira, and are therefore included in this model (where `issue_type='epic'`). |
| [jira__project_enhanced](https://github.com/fivetran/dbt_jira/blob/master/models/jira__project_enhanced.sql)            | Each record represents a project, enriched with data about the users involved, how many issues have been opened or closed, the velocity of work, and the breadth of the project (ie its components and epics). |
| [jira__user_enhanced](https://github.com/fivetran/dbt_jira/blob/master/models/jira__user_enhanced.sql)            | Each record represents a user, enriched with metrics regarding their open issues, completed issues, the projects they work on, and the velocity of their work. |

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

```yml
# packages.yml
packages:
  - package: fivetran/jira
    version: [">=0.8.0", "<0.9.0"]
```

## Configuration
By default, this package looks for your Jira data in the `jira` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your Jira data is, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
    jira_database: your_database_name
    jira_schema: your_schema_name
```

### Daily Issue Field History Columns
The `jira__daily_issue_field_history` model generates historical data for the columns specified by the `issue_field_history_columns` variable. By default, the only columns tracked are `status` and `sprint`, but all fields found in the `field_name` column within the Jira `FIELD` table can be included in this model. The most recent value of any tracked column is also captured in `jira__issue_enhanced`.

**If you would like to change these columns, add the following configuration to your dbt_project.yml file. Then, after adding the columns to your `dbt_project.yml` file, run the `dbt run --full-refresh` command to fully refresh any existing models.**

```yml
# dbt_project.yml

...
config-version: 2

vars:
  jira:
    issue_field_history_columns: ['the', 'list', 'of', 'field', 'names']
```

> Note: `sprint` and `status` will always be tracked, as they are necessary for creating common agile reports.

### Extending an Issue's History Period
This package will create a row in `jira__daily_issue_field_history` for each day that an issue is open or being updated. For currently open issues, the latest date will be the current date. For closed issues, the latest date will be  when the issue was last resolved or updated in any way, plus a _buffer period_ that is by default equal to 1 month. This buffer exists for two reasons:
1. The daily issue field history model is materialized incrementally, and if your closed issues are being opened or updated often, this will avoid requiring a full refresh to catch these changes.
2. You may want to create a longer timeline of issues, regardless of their status, for easier reporting.

If you would like to extend this buffer period to longer than 1 month, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  jira_issue_history_buffer: integer_number_of_months # default is an interval of 1 month
```

### Disabling Models
It's possible that your Jira connector does not sync every table that this package expects. If your syncs exclude certain tables, it is because you either don't use that functionality in Jira or actively excluded some tables from your syncs. To disable the corresponding functionality in the package, you must add the relevant variables. By default, all variables are assumed to be `true`. Add variables for only the tables you would like to disable:  

```yml
# dbt_project.yml

...
config-version: 2

vars:
  jira_using_sprints: false # Disable if you do not have the sprint table, or if you do not want sprint related metrics reported
  jira_using_versions: false # Disable if you do not have the version table, or if you do not want version related metrics reported
  jira_using_components: false # Disable if you do not have the component table, or if you do not want component related metrics reported
  jira_using_priorities: false # disable if you are not using priorities in Jira
  jira_include_comments: false # this package aggregates issue comments so that you have a single view of all your comments in the jira__issue_enhanced table. This can cause limit errors if you have a large dataset. Disable to remove this functionality.
```

### Changing the Build Schema
By default this package will build the Jira staging models within a schema titled (<target_schema> + `_stg_jira`) and Jira final models within a schema titled (<target_schema> + `jira`) in your target database. If this is not where you would like your modeled Jira data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
models:
    jira:
      +schema: my_new_schema_name # leave blank for just the target_schema
    jira_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
```

## Contributions
Don't see a model or specific metric you would have liked to be included? Notice any bugs when installing 
and running the package? If so, we highly encourage and welcome contributions to this package! 
Please create issues or open PRs against `main`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Database Support
This package has been tested on BigQuery, Snowflake, Redshift, and Postgres.

## Resources:
- Provide [feedback](https://www.surveymonkey.com/r/DQ7K7WW) on our existing dbt packages or what you'd like to see next
- Have questions or feedback, or need help? Book a time during our office hours [here](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or shoot us an email at solutions@fivetran.com
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn how to orchestrate your models with [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt)
- Learn more about Fivetran overall [in our docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
