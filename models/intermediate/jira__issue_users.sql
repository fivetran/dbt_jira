-- just grabs user attributes for issue assignees and reporters 
with issue as (

    select *
    from {{ var('issue') }}

),

user as (

    select *
    from {{ var('user') }}
),

issue_user_join as (

    select
        issue.issue_id,
        issue.assignee_user_id,
        assignee.user_display_name as assignee_name,
        assignee.time_zone as assignee_timezone,
        assignee.email as assignee_email,

        -- note: reporter is the user who created the issue by default, 
        -- but this can be changed in-app (making it potentially different from `creator`)
        issue.reporter_user_id,
        reporter.email as reporter_email,
        reporter.user_display_name as reporter_name,
        reporter.time_zone as reporter_timezone
        
        
    from issue
    left join user assignee on issue.assignee_user_id = assignee.user_id 
    left join user reporter on issue.reporter_user_id = reporter.user_id

    group by {{ dbt_utils.group_by(n=9) }}
)

select * from issue_user_join