# Decision Log
In creating this package, which is meant for a wide range of use cases, we had to take opinionated stances on a few different questions we came across during development. We've consolidated significant choices we made here, and will continue to update as the package evolves.

## Conversation Aggregation Guard Against String Length Limits
Jira issues with a large volume of comments can cause `string_agg` to exceed a warehouse's string length limit, producing a runtime error (`String '...' is too long and would be truncated`). Rather than disabling the `conversation` field entirely or letting runs fail, the package uses a single-pass `CASE WHEN` that sums the exact rendered character length of each comment row (`length(rendered_comment || '\n')`) before aggregating. If the total would exceed the warehouse limit, `conversation` returns `'conversation too long to render'` instead. The `count_comments` field is always populated regardless.

The threshold is warehouse-specific and exposed as `jira_conversation_char_limit` for users who need to lower it. See the [README](https://github.com/fivetran/dbt_jira#controlling-conversation-aggregations-in-jira__issue_enhanced) for configuration details.

Per-warehouse behavior:
- **Snowflake**: guard active, default limit 16,777,216 chars (documented LISTAGG hard limit)
- **BigQuery**: guard active, default limit 16,777,216 chars
- **Redshift**: guard active, default limit 65,535 chars (VARCHAR max); conversations remain disabled by default via `jira_include_conversations` to avoid a schema change for existing users, but enabling them is now safe
- **Postgres**: no guard — TEXT supports ~1 GB, overflow is not a practical concern
- **Databricks**: no guard — Spark STRING supports ~2 GB and `collect_set` deduplicates rows before aggregating, making overflow extremely unlikely

## Enhancing Jira Sprint Reporting with Flexible Metrics
To improve sprint reporting in the Jira dbt package, we introduced two new models, `jira__daily_sprint_issue_history` and `jira__sprint_enhanced`, designed to capture key sprint metrics such as velocity, time tracking, and story point completion.
  
If further refinements or reporting is needed for the sprint report, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_jira/issues).
