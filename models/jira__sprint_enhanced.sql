{{ config(enabled=var('jira_using_sprints', True)) }}

{% set using_teams = var('jira_using_teams', True) %}

with daily_sprint_issue_history as (

    select *
    from {{ ref('jira__daily_sprint_issue_history') }}
),

sprint_metrics_grouped as (

    select
        source_relation,
        sprint_id,
        team,
        sprint_name,
        sprint_started_at,
        sprint_ended_at,
        sprint_completed_at,
        board_id,
        original_estimate_seconds,
        remaining_estimate_seconds,
        time_spent_seconds
    from daily_sprint_issue_history
    {{ dbt_utils.group_by(11) }}
),

sprint_issue_metrics as (

    select
        sprint_id,
        source_relation,
        count(distinct issue_id) as sprint_issues,
        count(distinct assignee_user_id) as sprint_assignees,
        count(distinct (case when is_sprint_active and is_issue_open then issue_id end)) as open_sprint_issues,
        count(distinct (case when date_day >= cast(issue_resolved_at as date)
            and issue_resolved_at <= sprint_ended_at
            then issue_id end)) as resolved_sprint_issues
    from daily_sprint_issue_history
    {{ dbt_utils.group_by(2) }}
),

sprint_start_metrics as (

    select
        sprint_id,
        source_relation,
        sum(case when story_points is null then 0 else story_points end) as story_points_committed,
        sum(case when story_point_estimate is null then 0 else story_point_estimate end) as story_point_estimate_committed,
        count(distinct issue_id) as issues_committed
    from daily_sprint_issue_history
    -- to capture both sprints that have started or will start in the future
    where date_day = cast(sprint_started_at as date)
        or (date_day < cast(sprint_started_at as date)
            and date_day = cast({{ dbt.current_timestamp() }} as date))
    {{ dbt_utils.group_by(2) }}
),

sprint_end_metrics as (

    select
        sprint_id,
        source_relation,
        sum(case when story_points is null then 0 else story_points end) as story_points_end,
        sum(case when story_point_estimate is null then 0 else story_point_estimate end) as story_point_estimate_end,
        sum(case when is_issue_resolved_in_sprint then story_points else 0 end) as story_points_completed,
        sum(case when is_issue_resolved_in_sprint then story_point_estimate else 0 end) as story_point_estimate_completed
    from daily_sprint_issue_history
    where date_day = cast(sprint_ended_at as date)
    group by 1, 2
), 

final as (

    select
        sprint_metrics_grouped.source_relation,
        sprint_metrics_grouped.sprint_id,
        sprint_metrics_grouped.team,
        sprint_metrics_grouped.sprint_name,
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
        sum(case when sprint_metrics_grouped.original_estimate_seconds is null then 0 else sprint_metrics_grouped.original_estimate_seconds end) as original_estimate_seconds,
        sum(case when sprint_metrics_grouped.remaining_estimate_seconds is null then 0 else sprint_metrics_grouped.remaining_estimate_seconds end) as remaining_estimate_seconds,
        sum(case when sprint_metrics_grouped.time_spent_seconds is null then 0 else sprint_metrics_grouped.time_spent_seconds end) as time_spent_seconds
    from sprint_metrics_grouped
    left join sprint_issue_metrics
        on sprint_metrics_grouped.sprint_id = sprint_issue_metrics.sprint_id
        and sprint_metrics_grouped.source_relation = sprint_issue_metrics.source_relation
    left join sprint_start_metrics
        on sprint_metrics_grouped.sprint_id = sprint_start_metrics.sprint_id
        and sprint_metrics_grouped.source_relation = sprint_start_metrics.source_relation
    left join sprint_end_metrics
        on sprint_metrics_grouped.sprint_id = sprint_end_metrics.sprint_id
        and sprint_metrics_grouped.source_relation = sprint_end_metrics.source_relation
    {{ dbt_utils.group_by(19) }}
)

select * 
from final