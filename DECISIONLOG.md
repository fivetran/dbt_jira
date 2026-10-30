# Decision Log
In creating this package, which is meant for a wide range of use cases, we had to take opinionated stances on a few different questions we came across during development. We've consolidated significant choices we made here, and will continue to update as the package evolves.

## Conversation Aggregation Guard Against String Length Limits
Jira issues with a large volume of comments can cause the `conversation` field to exceed the warehouse string size limit, resulting in a runtime error. To prevent this, the package now checks the total conversation length for each issue before aggregation on Snowflake and BigQuery.

If an issue exceeds the configured limit, `conversation` returns `'conversation too long to render'` instead of failing the model. The `count_comments` field is still populated, so users can identify issues with large comment volumes even when the full conversation cannot be rendered.

The default threshold is `16,777,216` characters for Snowflake and BigQuery. You can override this value with `jira_conversation_char_limit` if you need a lower threshold. See the [README](https://github.com/fivetran/dbt_jira#controlling-conversation-aggregations-in-jira__issue_enhanced) for configuration details.

Per-warehouse behavior:
- **Snowflake and BigQuery**: Overflow protection is enabled by default. If an issue has enough comments for `conversation` to exceed the warehouse string size limit, `conversation` returns `'conversation too long to render'` instead of failing. The default limit is `16,777,216` characters.
- **Redshift**: Overflow protection is not currently applied. Redshift has a much lower string size limit, but it does not support the SQL pattern used by this guard, so adding the same protection would require a more significant model change. Conversations are disabled on Redshift by default with `jira_include_conversations`, so overflow is only a risk for users who explicitly enable conversations and have issues with very large comment volumes. If you need Redshift overflow protection, [open a GitHub issue](https://github.com/fivetran/dbt_jira/issues/new/choose).
- **Postgres and Databricks**: Overflow protection is not applied because their string/text limits make this issue unlikely in practice.

## Enhancing Jira Sprint Reporting with Flexible Metrics
To improve sprint reporting in the Jira dbt package, we introduced two new models, `jira__daily_sprint_issue_history` and `jira__sprint_enhanced`, designed to capture key sprint metrics such as velocity, time tracking, and story point completion.
  
If further refinements or reporting is needed for the sprint report, customers can submit a feature request by clicking the [New Issue button in our package issue page](https://github.com/fivetran/dbt_jira/issues).
