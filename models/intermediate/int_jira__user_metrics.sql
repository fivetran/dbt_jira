with issue as (

    select *
    from {{ ref('jira__issue_enhanced') }} 
    where assignee_user_id is not null
),

calculate_medians as (

    select 
        assignee_user_id as user_id,
        round( cast( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is not null then last_assignment_duration_seconds end', 
                    partition_field='assignee_user_id', percent='0.5') }} as {{ dbt_utils.type_numeric() }}), 0) as median_close_time_seconds,
        round( cast( {{ fivetran_utils.percentile(percentile_field='case when resolved_at is null then last_assignment_duration_seconds end', 
                    partition_field='assignee_user_id', percent='0.5') }} as {{ dbt_utils.type_numeric() }}), 0) as median_age_currently_open_seconds

    from issue

    {% if target.type == 'postgres' %} group by 1 {% endif %}
),

-- grouping because the medians were calculated using window functions (except postgres)
median_metrics as (

    select 
        user_id, 
        median_close_time_seconds, 
        median_age_currently_open_seconds

    from calculate_medians
    group by 1,2,3
),


user_issues as (

    select
        assignee_user_id as user_id,
        sum(case when resolved_at is not null then 1 else 0 end) as count_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as count_open_issues,

        sum(case when resolved_at is not null then last_assignment_duration_seconds end) as sum_current_open_seconds,
        sum(case when resolved_at is null then last_assignment_duration_seconds end) as sum_close_time_seconds

    from issue

    group by 1

),

calculate_avg_metrics as (

    select 
        user_id,
        count_closed_issues,
        count_open_issues,

        case when count_closed_issues = 0 then 0 else
        round( cast(sum_close_time_seconds * 1.0 / count_closed_issues as {{ dbt_utils.type_numeric() }} ), 0) end as avg_close_time_seconds,

        case when count_open_issues = 0 then 0 else
        round( cast(sum_current_open_seconds * 1.0 / count_open_issues as {{ dbt_utils.type_numeric() }} ), 0) end as avg_age_currently_open_seconds

    from user_issues
),

join_metrics as (

    select
        calculate_avg_metrics.*,
        round( cast(calculate_avg_metrics.avg_close_time_seconds / 86400.0 as {{ dbt_utils.type_numeric() }} ), 0) as avg_close_time_days,
        round( cast(calculate_avg_metrics.avg_age_currently_open_seconds / 86400.0 as {{ dbt_utils.type_numeric() }} ), 0) as avg_age_currently_open_days,

        median_metrics.median_close_time_seconds,
        median_metrics.median_age_currently_open_seconds,

        round( cast(median_metrics.median_close_time_seconds / 86400.0 as {{ dbt_utils.type_numeric() }} ), 0) as median_close_time_days,
        round( cast(median_metrics.median_age_currently_open_seconds / 86400.0 as {{ dbt_utils.type_numeric() }} ), 0) as median_age_currently_open_days
        
    from calculate_avg_metrics
    left join median_metrics using(user_id)
)

select * from join_metrics