# Jira Analysis
> Note: The compiled sql within the analysis folder references the final model [jira__daily_issue_field_history](https://github.com/fivetran/dbt_jira/blob/master/models/jira__daily_issue_field_history.sql). As such, prior to 
compiling the provided sql to analyze issue status category metrics, you must first execute `dbt run`.
 

## Analysis SQL
| **sql**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [jira__daily_issue_status_category_analysis](https://github.com/fivetran/dbt_jira/blob/master/analysis/jira__daily_issue_status_category_analysis.sql) | The output of the compiled sql will generate daily metrics for issue status categories including counts of issues in each status, new issues entering statuses, 30-day rolling averages, and average days to completion. The SQL command references the `jira__daily_issue_field_history` model and aggregates issue status data by project and team across status categories (To Do, In Progress, Done). This will provide comprehensive insights into your team's workflow performance and issue progression patterns. Aggregation granularity can be adjusted by adding/removing field names in the `issue_field_history_columns` var in your dbt project.yml. `status` can be used in place of `status_category` if desired by removing the category mapping cte and adjusting the joins accordingly. |


## SQL Compile Instructions
Leveraging the above sql is made possible by the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/). In order to
compile the sql, you will perform the following steps:
- Execute `dbt run` to create the package models.
- Execute `dbt compile` to generate the target specific sql.
- Navigate to your project's `/target/compiled/jira/analysis` directory.
- Copy the `jira__daily_issue_status_category_analysis` code and run in your data warehouse.
- Confirm the issue status category metrics match your expected workflow patterns.
- Analyze the daily counts, rolling averages, and completion metrics to identify trends and bottlenecks in your development process.

## Contributions
Don't see a compiled sql statement you would have liked to be included? Notice any bugs when compiling
and running the analysis sql? If so, we highly encourage and welcome contributions to this package! 
Please create issues or open PRs against `master`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Database Support
This package has been tested on BigQuery, Snowflake and Redshift.

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_jira/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).