-- just grabs user attributes for issue assignees and reporters 

with issue as (

    {% set except_columns = ["revised_parent_issue_id", "parent_issue_id"] %}

    select
        {{ dbt_utils.star(from=ref('int_jira__issue_type_parents'), 
                            except= except_columns | upper if target.type == 'snowflake' else except_columns) }}

        , coalesce(revised_parent_issue_id, parent_issue_id) as parent_issue_id

    
    from {{ ref('int_jira__issue_type_parents') }}

),

-- user is a reserved keyword in AWS
jira_user as (

    select *
    from {{ var('user') }}
),

issue_user_join as (

    select
        issue.*,
        assignee.user_display_name as assignee_name,
        assignee.time_zone as assignee_timezone,
        assignee.email as assignee_email,
        reporter.email as reporter_email,
        reporter.user_display_name as reporter_name,
        reporter.time_zone as reporter_timezone
        
        
    from issue
    left join jira_user as assignee on issue.assignee_user_id = assignee.user_id 
    left join jira_user as reporter on issue.reporter_user_id = reporter.user_id

)

select * 
from issue_user_join