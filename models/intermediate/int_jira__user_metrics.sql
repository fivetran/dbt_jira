with issue as (

    select *
    from {{ ref('jira__issue_enhanced') }} 
    where assignee_user_id is not null
),

user_issues as (

    select
        assignee_user_id as user_id,
        sum(case when resolved_at is not null then 1 else 0 end) as n_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as n_open_issues,

        sum(case when resolved_at is not null then last_assignment_duration_seconds end) as sum_current_open_seconds,
        sum(case when resolved_at is null then last_assignment_duration_seconds end) as sum_close_time_seconds

    from issue

    group by 1

),

calculate_metrics as (

    select 
        user_id,
        n_closed_issues,
        n_open_issues,

        case when n_closed_issues = 0 then 0 else
        round( sum_close_time_seconds * 1.0 / n_closed_issues, 0) end as avg_close_time_seconds,

        case when n_open_issues = 0 then 0 else
        round( sum_current_open_seconds * 1.0 / n_open_issues, 0) end as avg_age_currently_open_seconds

    from user_issues
)

select * from calculate_metrics