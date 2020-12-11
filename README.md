# Jira

This package models Jira data from [Fivetran's connector](https://fivetran.com/docs/applications/jira). It uses data in the format described by [this ERD](https://docs.google.com/presentation/d/1UPq2CWnqQpbjLxkTrcWvAekaZ0o0OdzXODTVmUXeGvs/edit#slide=id.g5f1e6b049a_8_0). Note: this schema applies to Jira connections set up or fully resynced after September 10, 2020.

This package enables you to better understand the workload and performance of your organization through Jira issues. It achieves this by:
- Enriching the core issue table with relevant data and limited metrics.
- Creating a daily issue field history table to enable the quick creation of agile reports such as burndown charts.
- Aggregating issue metrics along along epics, users, projects, and sprints.

> The Jira dbt package is compatible with BigQuery, Redshift, and Snowflake destinations.

## Models - transformation package version

This package contains transformation models, designed to work simultaneously with our [Jira source package](https://github.com/fivetran/dbt_jira_source). A dependency on the source package is declared in this package's `packages.yml` file, so it will automatically download when you run `dbt deps`. The primary outputs of this package are described below. Intermediate models are used to create these output models.

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_field_history](https://github.com/fivetran/dbt_jira/blob/master/models/jira__daily_issue_field_history.sql)             | Each record represents a day in which an issue remained open, complete with the values of any fields specified by `issue_field_history_columns`. Note: this model (and its parents) is materialized as as an incremental model.  |
| jira__issue_enhanced            | Each record represents a Jira issue, enriched with data about its current assignee, reporter, sprint, epic, project, resolution, issue type, priority, and status. Also includes metrics reflecting assignments, sprint rollovers, and re-openings. |
| jira__project_metrics            | Each record represents a project, enriched with data about the users involved, how many issues are open/closed |
| jira__user_metrics            | Each record represents a user, enriched with metrics regarding their open issues, completed issues, the projects they work on, and the velocity of their work. |
| jira__epic_metrics            | TODO - maybe?, people did ask for this.... and can disable, though it is super easy to pull this stuff from issue_enhanced. This may be particularly helpful |
| jira__sprint_metrics            | TODO - maybe? so people can join easily with daily field history |

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

## Configuration
By default, this package looks for your Jira data in the `jira` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your Jira data is, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
    connector_database: your_database_name
    connector_schema: your_schema_name
```

### Daily Issue Field History Columns
The `jira__daily_issue_field_history` model generates historical data for the columns specified by the `issue_field_history_columns` variable. By default, the columns tracked are `status` and `sprint`. 

If you would like to change these columns, add the following configuration to your dbt_project.yml file. Then, after adding the columns to your `dbt_project.yml` file, run the `dbt run --full-refresh` command to fully refresh any existing models.

```yml
# dbt_project.yml

...
config-version: 2

vars:
  jira:
    issue_field_history_columns: ['the', 'list', 'of', 'field', 'names']
```

Note: all field names can be found by querying `jira.field`.

## Contributions
Additional contributions to this package are very welcome! Please create issues
or open PRs against `master`. Check out 
[this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) 
on the best workflow for contributing to a package.

## Resources:
- Provide [feedback](https://www.surveymonkey.com/r/DQ7K7WW) on our existing dbt packages or what you'd like to see next
- Have questions or feedback, or need help? Book a time during our office hours [here](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or shoot us an email at solutions@fivetran.com.
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn how to orchestrate dbt transformations with Fivetran [here](https://fivetran.com/docs/transformations/dbt).
- Learn more about Fivetran overall [in our docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
