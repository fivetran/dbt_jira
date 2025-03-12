{{
    config(
        enabled=var('jira_using_sprints', True),
        materialized='incremental' if jira_is_incremental_compatible() else 'table',
        partition_by = {'field': 'date_week', 'data_type': 'date'}
            if target.type not in ['spark', 'databricks'] else ['date_week'],
        cluster_by = ['date_week'],
        unique_key='sprint_issue_day_id',
        incremental_strategy = 'insert_overwrite' if target.type in ('bigquery', 'databricks', 'spark') else 'delete+insert',
        file_format='delta'
    )
}}

with daily_issue_field_history as (

    select *
    from {{ ref('jira__daily_issue_field_history') }}

    {% if is_incremental() %}
    {% set max_date_week = jira.jira_lookback(from_date='max(date_day)', datepart='week', interval=var('lookback_window', 1)) %}
    where cast(date_day as date) >= {{ max_date_week }}
    {% endif %}
),

issue_multiselect_history as (

    select *
    from {{ ref('int_jira__issue_multiselect_history') }}
    {% if is_incremental() %}
    where cast(updated_at as date) >= {{ max_date_week }}
    {% endif %}
),

sprint as (

    select *
    from {{ var('sprint') }} 
),

issue as (

    select *
    from {{ var('issue') }} 
),

issue_sprint_history as (

    select
        issue_multiselect_history.field_value as sprint_id,
        issue_multiselect_history.issue_id,
        issue_multiselect_history.updated_at as issue_assigned_to_sprint_at,
        sprint.started_at as sprint_started_at,
        sprint.ended_at as sprint_ended_at,
        sprint.completed_at as sprint_completed_at,
        sprint.board_id,
        issue.created_at as issue_created_at,
        issue.resolved_at as issue_resolved_at,
        issue.assignee_user_id,
        issue.original_estimate_seconds,
        issue.remaining_estimate_seconds,
        issue.time_spent_seconds
    from issue_multiselect_history
    --Since we are only concerned with sprint data, thought it best to avoid issues not tied to sprints, hence the inner join.
    inner join issue
        on issue.issue_id = issue_multiselect_history.issue_id
    inner join sprint
        on issue_multiselect_history.field_value = cast(sprint.sprint_id as {{ dbt.type_string() }}) 
    where issue_multiselect_history.field_name = 'sprint'
        and issue_multiselect_history.is_active = true
        and issue_multiselect_history.field_value is not null
),

issue_sprint_daily_history as (

    select
        issue_sprint_history.sprint_id,
        issue_sprint_history.issue_id,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        issue_sprint_history.issue_assigned_to_sprint_at,
        issue_sprint_history.sprint_started_at,
        issue_sprint_history.sprint_ended_at,
        issue_sprint_history.sprint_completed_at,
        issue_sprint_history.board_id,
        issue_sprint_history.issue_created_at,
        issue_sprint_history.issue_resolved_at,
        issue_sprint_history.assignee_user_id,
        issue_sprint_history.original_estimate_seconds,
        issue_sprint_history.remaining_estimate_seconds,
        issue_sprint_history.time_spent_seconds,
        daily_issue_field_history.status,
        daily_issue_field_history.status_id,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate
    from issue_sprint_history  
    left join daily_issue_field_history 
        on issue_sprint_history.issue_id = daily_issue_field_history.issue_id 
),

issue_sprint_statuses as (

    select 
        issue_sprint_daily_history.*,
        case when date_day >= cast(sprint_started_at as date) and date_day <= cast(sprint_ended_at as date) then true else false end as is_sprint_active,
        case when date_day >= cast(sprint_completed_at as date) then true else false end as is_sprint_completed,
        case when date_day >= cast(issue_created_at as date) and issue_resolved_at is null then true else false end as is_issue_open,
        case when date_day >= cast(issue_resolved_at as date) and issue_resolved_at <= sprint_ended_at then true else false end as is_issue_resolved_in_sprint,
        case when date_day >= cast(sprint_started_at as date) and date_day <= cast(sprint_ended_at as date)
            then {{ dbt.datediff('date_day', 'sprint_ended_at', 'day') }} else null end as days_left_in_sprint
    from issue_sprint_daily_history
),

surrogate_key as (

    select *,
        {{ dbt_utils.generate_surrogate_key(['date_day','sprint_id','issue_id']) }} as sprint_issue_day_id
    from issue_sprint_statuses
) 

select *
from surrogate_key