with issue as (

    select * 
    from {{ ref('jira__issue_enhanced') }}
),


project_issues as (
    select
        project_id,
        sum(case when resolved_at is not null then 1 else 0 end) as n_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as n_open_issues,

        -- using the below to calculate averages
        sum(case when resolved_at is null and assignee_user_id is not null then 1 else 0 end) as n_open_assigned_issues,
        sum(case when resolved_at is not null and assignee_user_id is not null then 1 else 0 end) as n_closed_assigned_issues,

        -- close time 
        sum(case when resolved_at is not null then open_duration_seconds else 0 end) as sum_close_time_seconds,
        sum(case when resolved_at is not null then any_assignment_duration_seconds else 0 end) as sum_assigned_close_time_seconds,

        -- age of currently open tasks
        sum(case when resolved_at is null then open_duration_seconds else 0 end) as sum_currently_open_duration_seconds,
        sum(case when resolved_at is null then any_assignment_duration_seconds else 0 end) as sum_currently_open_assigned_duration_seconds

    from issue

    group by 1
),

calculate_metrics as (

    select
        project_id,
        n_closed_issues,
        n_open_issues,
        n_open_assigned_issues,

        case when n_closed_issues = 0 then 0 else
        round( sum_close_time_seconds * 1.0 / n_closed_issues, 0) end as avg_close_time_seconds,

        case when n_closed_assigned_issues = 0 then 0 else
        round( sum_assigned_close_time_seconds * 1.0 / n_closed_assigned_issues, 0) end as avg_assigned_close_time_seconds,

        case when n_open_issues = 0 then 0 else
        round( sum_currently_open_duration_seconds * 1.0 / n_open_issues, 0) end as avg_age_currently_open_seconds,

        case when n_open_assigned_issues = 0 then 0 else
        round( sum_currently_open_assigned_duration_seconds * 1.0 / n_open_assigned_issues, 0) end as avg_age_currently_open_assigned_seconds

    from project_issues
)

select * 
from calculate_metrics