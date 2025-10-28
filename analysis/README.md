# Jira Analysis
> Note: The compiled sql within the analysis folder references the final model [jira__issue_status_transitions](https://github.com/fivetran/dbt_jira/blob/master/models/jira__issue_status_transitions.sql). As such, prior to
compiling the provided sql to analyze issue status category metrics, you must first execute `dbt run`.


## Analysis SQL
| **sql**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_status_category_analysis](https://github.com/fivetran/dbt_jira/blob/master/analysis/jira__daily_issue_status_category_analysis.sql) | The output of the compiled sql will generate daily metrics for issue status categories by joining status transitions with field history data. The analysis aggregates data by date, project, team, and status category to provide: count of distinct issues in each status category, average days spent in status category, and counts of issues that started work, completed work, or reopened work. The SQL references the `jira__issue_status_transitions` and `jira__timestamp_issue_field_history` models. Aggregation granularity can be adjusted by adding/removing field names in the `issue_field_history_columns` var in your dbt project.yml. `status` can be used in place of `status_category` if desired by modifying the model accordingly. |




## SQL Compile Instructions
Leveraging the above sql is made possible by the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/). In order to
compile the sql, you will perform the following steps:
- Execute `dbt run` to create the package models.
- Execute `dbt compile` to generate the target specific sql.
- Navigate to your project's `/target/compiled/jira/analysis` directory.
- Copy the `jira__daily_issue_status_category_analysis` code and run in your data warehouse.
- Confirm the issue status category metrics match your expected workflow patterns.
- Analyze the daily counts, cumulative flow, and completion metrics to identify trends and bottlenecks in your development process.


## Contributions
Don't see a compiled sql statement you would have liked to be included? Notice any bugs when compiling
and running the analysis sql? If so, we highly encourage and welcome contributions to this package!
Please create issues or open PRs against `master`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.


## Database Support
This package has been tested on BigQuery, Snowflake and Redshift.


## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).

