{{ config(enabled=var('jira_using_sprints', True)) }}

with sprint as (

    select *
    from {{ var('sprint') }}
),

sprint_metrics as (

    select * 
    from {{ ref('int_jira__sprint_metrics') }}
),

issue_enhanced as (

    select *
    from {{ ref('jira__issue_enhanced') }}
),


sprint_time_metrics as (

    select 
        cast(sprint.sprint_id as {{ dbt.type_string() }}) as sprint_id
        , sprint.sprint_name 
        , sprint.board_id
        , sprint.started_at as sprint_started_at
        , sprint.ended_at as sprint_ended_at
        , sprint.completed_at as sprint_completed_at
        , coalesce(sprint.started_at <= {{ dbt.current_timestamp() }}
            and coalesce(sprint.completed_at, {{ dbt.current_timestamp() }}) >= {{ dbt.current_timestamp() }}  
            , false) as is_active_sprint -- If sprint doesn't have a start date, default to false. If it does have a start date, but no completed date, this means that the sprint is active. The ended_at timestamp is irrelevant here.
        , sum(case when issue_enhanced.current_story_points is null then 0 else issue_enhanced.current_story_points end) as current_story_points
        , sum(case when issue_enhanced.current_estimated_story_points is null then 0 else issue_enhanced.current_estimated_story_points end) as current_estimated_story_points
        , sum(case when issue_enhanced.original_estimate_seconds is null then 0 else issue_enhanced.original_estimate_seconds end) as sprint_original_estimate_seconds
        , sum(case when issue_enhanced.remaining_estimate_seconds is null then 0 else issue_enhanced.remaining_estimate_seconds end) as sprint_remaining_estimate_seconds
        , sum(case when issue_enhanced.time_spent_seconds is null then 0 else issue_enhanced.time_spent_seconds end) as sprint_time_spent_seconds
        , count(distinct issue_enhanced.issue_id) as issues_per_sprint
        , sum(case when issue_enhanced.resolved_at <= sprint.ended_at then 1 else 0 end) as issues_resolved_in_sprint
        , sum(issue_enhanced.count_sp_changes) as count_sp_changes
        , sum(issue_enhanced.count_estimated_sp_changes) as count_estimated_sp_changes
        {% if var('jira_using_sprints', True) %} 
        , sum(issue_enhanced.count_sprint_changes) as count_sprint_issue_changes
        {% endif %}
    from sprint
    left join issue_enhanced 
        on cast(sprint.sprint_id as {{ dbt.type_string() }}) = issue_enhanced.current_sprint_id
    {{ dbt_utils.group_by(6) }}
),

final as (

    select 
        sprint_time_metrics.*,
        sprint_metrics.count_closed_issues,
        sprint_metrics.count_open_issues,
        sprint_metrics.count_open_assigned_issues, 
        sprint_metrics.avg_close_time_days,
        sprint_metrics.avg_assigned_close_time_days,
        sprint_metrics.avg_age_currently_open_days,
        sprint_metrics.avg_age_currently_open_assigned_days,
        sprint_metrics.median_close_time_seconds,
        sprint_metrics.median_age_currently_open_seconds,
        sprint_metrics.median_assigned_close_time_seconds,
        sprint_metrics.median_age_currently_open_assigned_seconds,
        sprint_metrics.median_close_time_days,
        sprint_metrics.median_age_currently_open_days,
        sprint_metrics.median_assigned_close_time_days,
        sprint_metrics.median_age_currently_open_assigned_days 
    from sprint_time_metrics
    left join sprint_metrics    
        on sprint_time_metrics.sprint_id = sprint_metrics.current_sprint_id
)

select * 
from final