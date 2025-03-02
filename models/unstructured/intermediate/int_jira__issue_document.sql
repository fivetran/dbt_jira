{{ config(enabled=var('jira__unstructured_enabled', False)) }}

with issues as (
    select *
    from {{ var('issue') }}

), users as (
    select *
    from {{ var('user') }}

), issue_details as (
    select
        issues.issue_id,
        issues.issue_name,
        {{ jira.coalesce_cast(["users.user_display_name", "'UNKNOWN'"], dbt.type_string()) }} as user_name,
        {{ jira.coalesce_cast(["users.email", "'UNKNOWN'"], dbt.type_string()) }} as created_by,
        issues.created_at AS created_on,
        {{ jira.coalesce_cast(["issues.status_id", "'UNKNOWN'"], dbt.type_string()) }} as status,
        {{ jira.coalesce_cast(["issues.priority_id", "'UNKNOWN'"], dbt.type_string()) }} as priority
    from issues
    left join users
        on issues.reporter_user_id = users.user_id 
), 

final as (
    select
        issue_id,
        {{ dbt.concat([
            "'# issue : '", "issue_name", "'\\n\\n'",
            "'Created By : '", "user_name", "' ('", "created_by", "')\\n'",
            "'Created On : '", "created_on", "'\\n'",
            "'Status : '", "status", "'\\n'",
            "'Priority : '", "priority"
        ]) }} as issue_markdown
    from issue_details
)

select 
    *,
    {{ jira.count_tokens("issue_markdown") }} as issue_tokens
from final