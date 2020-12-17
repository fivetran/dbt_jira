with issue as (

    select * 
    from {{ ref('jira__issue_enhanced') }}
    where project_id is not null
),

median_metrics as (

    select 
        project_id, 
        median_close_time_seconds, 
        median_age_currently_open_seconds,
        median_assigned_close_time_seconds,
        median_age_currently_open_assigned_seconds

    from (
        select 
            project_id,
            round( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is not null then open_duration_seconds end', 
                        partition_field='project_id', percent='0.5') }}, 0) as median_close_time_seconds,
            round( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is null then open_duration_seconds end', 
                        partition_field='project_id', percent='0.5') }}, 0) as median_age_currently_open_seconds,

            round( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is not null then any_assignment_duration_seconds end', 
                        partition_field='project_id', percent='0.5') }}, 0) as median_assigned_close_time_seconds,
            round( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is null then any_assignment_duration_seconds end', 
                        partition_field='project_id', percent='0.5') }}, 0) as median_age_currently_open_assigned_seconds

        from issue
    )
    group by 1,2,3,4,5
),


-- get appropriate counts + sums to calculate averages
project_issues as (
    select
        project_id,
        sum(case when resolved_at is not null then 1 else 0 end) as n_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as n_open_issues,

        -- using the below to calculate averages

        -- assigned issues
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

calculate_avg_metrics as (

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
),

join_metrics as (

    select
        calculate_avg_metrics.*,
        median_metrics.median_close_time_seconds, 
        median_metrics.median_age_currently_open_seconds,
        median_metrics.median_assigned_close_time_seconds,
        median_metrics.median_age_currently_open_assigned_seconds
        
    from calculate_avg_metrics
    left join median_metrics using(project_id)
)

select * from join_metrics