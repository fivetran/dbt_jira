# Jira Analysis
> Note: The compiled sql within the analysis folder references the final models [jira__issue_status_transitions](https://github.com/fivetran/dbt_jira/blob/master/models/jira__issue_status_transitions.sql), [jira__timestamp_issue_field_history](https://github.com/fivetran/dbt_jira/blob/master/models/jira__timestamp_issue_field_history), and [jira__daily_issue_field_history](https://github.com/fivetran/dbt_jira/blob/master/models/jira__daily_issue_field_history). As such, prior to
compiling the provided sql to analyze issue status category metrics, you must first execute `dbt run`.


## Analysis SQL
| **sql**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_status_category_analysis](https://github.com/fivetran/dbt_jira/blob/master/analysis/jira__daily_issue_status_category_analysis.sql) | The output of the compiled sql will generate daily counts of issues in each status category by date, project, and team. The analysis provides a snapshot view of how many issues are in each status category (To Do, In Progress, Done) on any given day. The SQL references the `jira__daily_issue_field_history` model and can be customized by adjusting the `issue_field_history_columns` var in your dbt_project.yml. `status` can be used in place of `status_category` if desired by modifying the model accordingly. |
| [jira__issue_transition_cumulative_flow_analysis](https://github.com/fivetran/dbt_jira/blob/master/analysis/jira__issue_transition_cumulative_flow_analysis.sql) | The output of the compiled sql will generate daily transition metrics for issue status categories with cumulative flow calculations. The analysis joins status transitions with field history data to provide: count of distinct issues transitioning into a new status category, cumulative count of issues in each status category over time, and counts of issues that started work, completed work, or reopened work. The SQL references the `jira__issue_status_transitions` and `jira__timestamp_issue_field_history` models. Aggregation granularity can be adjusted by adding/removing field names in the `issue_field_history_columns` var in your dbt_project.yml. `status` can be used in place of `status_category` if desired by modifying the model accordingly. |




## SQL Compile Instructions
Leveraging the above sql is made possible by the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/). In order to
compile the sql, you will perform the following steps:
- Execute `dbt run` to create the package models.
- Execute `dbt compile` to generate the target specific sql.
- Navigate to your project's `/target/compiled/jira/analysis` directory.
- Copy the desired analysis code (`jira__daily_issue_status_category_analysis` or `jira__issue_transition_cumulative_flow_analysis`) and run in your data warehouse.
- Confirm the issue status category metrics match your expected workflow patterns.
- Analyze the daily counts, transition metrics, and cumulative flow data to identify trends and bottlenecks in your development process.


## Contributions
Don't see a compiled sql statement you would have liked to be included? Notice any bugs when compiling
and running the analysis sql? If so, we highly encourage and welcome contributions to this package!
Please create issues or open PRs against `master`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.


## Database Support
This package has been tested on BigQuery, Snowflake, Redshift, Postgres, and Databricks.


## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).

