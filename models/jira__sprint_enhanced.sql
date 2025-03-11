{{ config(enabled=var('jira_using_sprints', True)) }}

with daily_sprint_issue_history as (

    select *
    from {{ ref('jira__daily_sprint_issue_history') }}
),

sprint_metrics_grouped as (

    select
        sprint_id, 
        sprint_started_at,
        sprint_ended_at,
        sprint_completed_at,
        board_id,
        original_estimate_seconds,
        remaining_estimate_seconds,
        time_spent_seconds
    from daily_sprint_issue_history
    {{ dbt_utils.group_by(8) }}
),

sprint_issue_metrics as (

    select 
        sprint_id,
        count(distinct issue_id) as sprint_issues,
        count(distinct assignee_user_id) as sprint_assignees,
        count(distinct (case when is_sprint_active and is_issue_open then issue_id end)) as open_sprint_issues,
        count(distinct (case when is_issue_resolved_in_sprint then issue_id end)) as resolved_sprint_issues,
        count(distinct (case when cast(issue_assigned_to_sprint_at as date) > cast(sprint_started_at as date)
            and cast(issue_assigned_to_sprint_at as date) < cast(sprint_ended_at as date)
            then issue_id else 0 end)) as injected_sprint_issues
    from daily_sprint_issue_history
    {{ dbt_utils.group_by(1) }}
),

sprint_start_metrics as (

    select 
        sprint_id,
        sum(story_points) as story_points_committed,
        sum(story_point_estimate) as story_point_estimate_committed,
        count(distinct issue_id) as issues_committed
    from daily_sprint_issue_history
    where date_day = cast(sprint_started_at as date)
    {{ dbt_utils.group_by(1) }}
),

sprint_end_metrics as (

    select 
        sprint_id,
        sum(story_points) as story_points_end,
        sum(story_point_estimate) as story_point_estimate_end,
        sum(case when is_issue_resolved_in_sprint then story_points else 0 end) as story_points_completed,
        sum(case when is_issue_resolved_in_sprint then story_point_estimate else 0 end) as story_point_estimate_completed
    from daily_sprint_issue_history
    where date_day = cast(sprint_ended_at as date)
    {{ dbt_utils.group_by(1) }}
),

final as (
    
    select 
        sprint_metrics_grouped.sprint_id, 
        sprint_metrics_grouped.sprint_started_at,
        sprint_metrics_grouped.sprint_ended_at,
        sprint_metrics_grouped.sprint_completed_at,
        sprint_metrics_grouped.board_id,
        sprint_start_metrics.story_points_committed,
        sprint_start_metrics.story_point_estimate_committed,
        sprint_end_metrics.story_points_end,
        sprint_end_metrics.story_point_estimate_end,
        sprint_end_metrics.story_points_completed,
        sprint_end_metrics.story_point_estimate_completed,
        sprint_issue_metrics.sprint_assignees,
        sprint_issue_metrics.sprint_issues,
        sprint_start_metrics.issues_committed,
        sprint_issue_metrics.open_sprint_issues,
        sprint_issue_metrics.resolved_sprint_issues,
        sprint_issue_metrics.injected_sprint_issues,
        sum(sprint_metrics_grouped.original_estimate_seconds) as original_estimate_seconds,
        sum(sprint_metrics_grouped.remaining_estimate_seconds) as remaining_estimate_seconds,
        sum(sprint_metrics_grouped.time_spent_seconds) as time_spent_seconds
    from sprint_metrics_grouped
    left join sprint_issue_metrics
        on sprint_metrics_grouped.sprint_id = sprint_issue_metrics.sprint_id
    left join sprint_start_metrics
        on sprint_metrics_grouped.sprint_id = sprint_start_metrics.sprint_id
    left join sprint_end_metrics
        on sprint_metrics_grouped.sprint_id = sprint_end_metrics.sprint_id
    {{ dbt_utils.group_by(17) }}
)

select * 
from final