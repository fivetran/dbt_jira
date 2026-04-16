{{ config(enabled=var('jira_using_sprints', True)) }}

{% set using_teams = var('jira_using_teams', True) and var('jira_sprint_enhanced_include_teams', True) %}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}

{# Base count of non-aggregated columns in final select (source_relation, sprint_id, sprint_name,
   sprint_started_at, sprint_ended_at, sprint_completed_at, board_id, sprint_assignees, sprint_issues,
   issues_committed, open_sprint_issues, resolved_sprint_issues = 12) #}
{% set final_group_by_count = 12
    + (1 if using_teams else 0)
    + (3 if include_story_points else 0)
    + (3 if include_story_point_estimate else 0) %}

with daily_sprint_issue_history as (

    select *
    from {{ ref('jira__daily_sprint_issue_history') }}

),

{% if using_teams %}

ranked_issue_sprint_team as (

    select
        source_relation,
        sprint_id,
        issue_id,
        team,
        row_number() over (
            partition by source_relation, sprint_id, issue_id
            order by
                case when team is not null then 0 else 1 end,
                date_day desc
        ) as row_num
    from daily_sprint_issue_history

),

resolved_issue_sprint_team as (

    select
        source_relation,
        sprint_id,
        issue_id,
        team
    from ranked_issue_sprint_team
    where row_num = 1

),

daily_sprint_issue_history_resolved as (

    select
        daily_sprint_issue_history.source_relation,
        daily_sprint_issue_history.issue_id,
        daily_sprint_issue_history.sprint_id,
        resolved_issue_sprint_team.team,
        daily_sprint_issue_history.date_day,
        daily_sprint_issue_history.sprint_name,
        daily_sprint_issue_history.sprint_started_at,
        daily_sprint_issue_history.sprint_ended_at,
        daily_sprint_issue_history.sprint_completed_at,
        daily_sprint_issue_history.board_id,
        daily_sprint_issue_history.assignee_user_id,
        daily_sprint_issue_history.original_estimate_seconds,
        daily_sprint_issue_history.remaining_estimate_seconds,
        daily_sprint_issue_history.time_spent_seconds,
        daily_sprint_issue_history.is_sprint_active,
        daily_sprint_issue_history.is_issue_open,
        daily_sprint_issue_history.issue_resolved_at,
        daily_sprint_issue_history.is_issue_resolved_in_sprint
        {% if include_story_points %}
        , daily_sprint_issue_history.story_points
        {% endif %}
        {% if include_story_point_estimate %}
        , daily_sprint_issue_history.story_point_estimate
        {% endif %}
    from daily_sprint_issue_history
    left join resolved_issue_sprint_team
        on daily_sprint_issue_history.source_relation = resolved_issue_sprint_team.source_relation
        and daily_sprint_issue_history.sprint_id = resolved_issue_sprint_team.sprint_id
        and daily_sprint_issue_history.issue_id = resolved_issue_sprint_team.issue_id

),

{% else %}

daily_sprint_issue_history_resolved as (

    select *
    from daily_sprint_issue_history

),

{% endif %}

sprint_issue_estimates as (

    -- Deduplicate to one row per issue per sprint (and team, if enabled) so that issues with identical estimate values are not collapsed before aggregation.
    select distinct
        source_relation,
        sprint_id,
        issue_id,
        {{ "team," if using_teams }}
        sprint_name,
        sprint_started_at,
        sprint_ended_at,
        sprint_completed_at,
        board_id,
        original_estimate_seconds,
        remaining_estimate_seconds,
        time_spent_seconds
    from daily_sprint_issue_history_resolved

),

sprint_metrics_grouped as (

    -- Sum estimate columns over the issue-deduplicated set to produce correct per-sprint totals.
    select
        source_relation,
        sprint_id,
        {{ "team," if using_teams }}
        sprint_name,
        sprint_started_at,
        sprint_ended_at,
        sprint_completed_at,
        board_id,
        sum(coalesce(original_estimate_seconds, 0)) as original_estimate_seconds,
        sum(coalesce(remaining_estimate_seconds, 0)) as remaining_estimate_seconds,
        sum(coalesce(time_spent_seconds), 0) as time_spent_seconds
    from sprint_issue_estimates
    {{ dbt_utils.group_by(8 if using_teams else 7) }}
),

sprint_issue_metrics as (

    select
        source_relation,
        sprint_id,
        {{ "team," if using_teams }}
        count(distinct issue_id) as sprint_issues,
        count(distinct assignee_user_id) as sprint_assignees,
        count(distinct (case when is_sprint_active and is_issue_open then issue_id end)) as open_sprint_issues,
        count(distinct (case when date_day >= cast(issue_resolved_at as date)
            and issue_resolved_at <= sprint_ended_at
            then issue_id end)) as resolved_sprint_issues
    from daily_sprint_issue_history_resolved
    {{ dbt_utils.group_by(3 if using_teams else 2) }}
),

sprint_start_metrics as (

    select
        source_relation,
        sprint_id,
        {{ "team," if using_teams }}
        {% if include_story_points %}
        sum(case when story_points is null then 0 else story_points end) as story_points_committed,
        {% endif %}
        {% if include_story_point_estimate %}
        sum(case when story_point_estimate is null then 0 else story_point_estimate end) as story_point_estimate_committed,
        {% endif %}
        count(distinct issue_id) as issues_committed
    from daily_sprint_issue_history_resolved
    -- to capture both sprints that have started or will start in the future
    where date_day = cast(sprint_started_at as date)
        or (date_day < cast(sprint_started_at as date)
            and date_day = cast({{ dbt.current_timestamp() }} as date))
    {{ dbt_utils.group_by(3 if using_teams else 2) }}
),

sprint_end_metrics as (

    select
        source_relation,
        sprint_id
        {{ ", team" if using_teams }}
        {% if include_story_points %}
        , sum(case when story_points is null then 0 else story_points end) as story_points_end
        , sum(case when is_issue_resolved_in_sprint then story_points else 0 end) as story_points_completed
        {% endif %}
        {% if include_story_point_estimate %}
        , sum(case when story_point_estimate is null then 0 else story_point_estimate end) as story_point_estimate_end
        , sum(case when is_issue_resolved_in_sprint then story_point_estimate else 0 end) as story_point_estimate_completed
        {% endif %}
    from daily_sprint_issue_history_resolved
    where date_day = cast(sprint_ended_at as date)
    {{ dbt_utils.group_by(3 if using_teams else 2) }}
),

final as (

    select
        sprint_metrics_grouped.source_relation,
        sprint_metrics_grouped.sprint_id,
        {{ "sprint_metrics_grouped.team," if using_teams }}
        sprint_metrics_grouped.sprint_name,
        sprint_metrics_grouped.sprint_started_at,
        sprint_metrics_grouped.sprint_ended_at,
        sprint_metrics_grouped.sprint_completed_at,
        sprint_metrics_grouped.board_id,
        {% if include_story_points %}
        sprint_start_metrics.story_points_committed,
        sprint_end_metrics.story_points_end,
        sprint_end_metrics.story_points_completed,
        {% endif %}
        {% if include_story_point_estimate %}
        sprint_start_metrics.story_point_estimate_committed,
        sprint_end_metrics.story_point_estimate_end,
        sprint_end_metrics.story_point_estimate_completed,
        {% endif %}
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
        {% if using_teams %}
        -- Explicit null handling ensures issues with no team assignment join correctly.
        and (
            sprint_metrics_grouped.team = sprint_issue_metrics.team
            or (sprint_metrics_grouped.team is null and sprint_issue_metrics.team is null)
        )
        {% endif %}
    left join sprint_start_metrics
        on sprint_metrics_grouped.sprint_id = sprint_start_metrics.sprint_id
        and sprint_metrics_grouped.source_relation = sprint_start_metrics.source_relation
        {% if using_teams %}
        and (
            sprint_metrics_grouped.team = sprint_start_metrics.team
            or (sprint_metrics_grouped.team is null and sprint_start_metrics.team is null)
        )
        {% endif %}
    left join sprint_end_metrics
        on sprint_metrics_grouped.sprint_id = sprint_end_metrics.sprint_id
        and sprint_metrics_grouped.source_relation = sprint_end_metrics.source_relation
        {% if using_teams %}
        and (
            sprint_metrics_grouped.team = sprint_end_metrics.team
            or (sprint_metrics_grouped.team is null and sprint_end_metrics.team is null)
        )
        {% endif %}
    {{ dbt_utils.group_by(final_group_by_count) }}
)

select * 
from final
