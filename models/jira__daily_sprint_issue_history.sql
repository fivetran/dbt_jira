{{
    config(
        enabled=var('jira_using_sprints', True),
        materialized='table',
        partition_by={'field': 'date_week', 'data_type': 'date'}
            if target.type not in ['spark', 'databricks'] else ['date_week']
    )
}}

with daily_issue_field_history as (

    select *
    from {{ ref('jira__daily_issue_field_history') }}
),

sprint_issue_pairing as (

    select
        issue_id,
        cast(field_value as {{ dbt.type_int() }}) as sprint_id,
        updated_at,
        is_active
    from {{ ref('int_jira__issue_multiselect_history') }}
    where field_name = 'sprint'
        and field_value is not null
),
sprint_activity_window as (

    select
        sprint_id,
        min(cast(updated_at as date)) as first_change_date,
        max(cast(updated_at as date)) as last_change_date
    from sprint_issue_pairing
    group by 1
),

ranked_sprint_updates as (
    
    select 
        sprint_issue_pairing.sprint_id,
        sprint_issue_pairing.issue_id,
        sprint_issue_pairing.updated_at,
        sprint_issue_pairing.is_active,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
        -- Rank updates within each `sprint_id, issue_id, date_day`
        row_number() over (
            partition by sprint_issue_pairing.sprint_id, 
                        sprint_issue_pairing.issue_id, 
                        daily_issue_field_history.date_day
            order by sprint_issue_pairing.updated_at desc
        ) as row_num
    from sprint_issue_pairing
    left join sprint_activity_window
        on sprint_activity_window.sprint_id = sprint_issue_pairing.sprint_id
    left join daily_issue_field_history 
        on sprint_issue_pairing.issue_id = daily_issue_field_history.issue_id
        -- Ensure tracking starts at the correct earliest date
        and cast(sprint_issue_pairing.updated_at as date) <= daily_issue_field_history.date_day
    where daily_issue_field_history.date_day <= {{ dbt.dateadd('month', 1, 'sprint_activity_window.last_change_date') }}
),

filtered_issue_sprint_history as (

    select 
        ranked_sprint_updates.*,
        sprint.sprint_name,
        sprint.started_at as sprint_started_at,
        sprint.ended_at as sprint_ended_at,
        sprint.completed_at as sprint_completed_at,
        sprint.board_id,
        issue.created_at as issue_created_at,
        issue.resolved_at as issue_resolved_at,
        issue.issue_key,
        issue.assignee_user_id,
        issue.assignee_name,
        issue.original_estimate_seconds,
        issue.remaining_estimate_seconds,
        issue.time_spent_seconds
    from ranked_sprint_updates
    inner join {{ ref('jira__issue_enhanced') }} issue
        on ranked_sprint_updates.issue_id = issue.issue_id
    inner join {{ var('sprint') }} sprint
        on ranked_sprint_updates.sprint_id = sprint.sprint_id
    where row_num = 1 --Keep only the last update per sprint-issue-date_day
),

issue_sprint_daily_history as (

    select
        filtered_issue_sprint_history.sprint_id,
        filtered_issue_sprint_history.issue_id,
        filtered_issue_sprint_history.issue_key,
        filtered_issue_sprint_history.date_day,
        filtered_issue_sprint_history.date_week,
        filtered_issue_sprint_history.updated_at,
        filtered_issue_sprint_history.sprint_name,
        filtered_issue_sprint_history.sprint_started_at,
        filtered_issue_sprint_history.sprint_ended_at,
        filtered_issue_sprint_history.sprint_completed_at,
        filtered_issue_sprint_history.board_id,
        filtered_issue_sprint_history.issue_created_at,
        filtered_issue_sprint_history.issue_resolved_at,
        filtered_issue_sprint_history.assignee_user_id,
        filtered_issue_sprint_history.assignee_name,
        filtered_issue_sprint_history.original_estimate_seconds,
        filtered_issue_sprint_history.remaining_estimate_seconds,
        filtered_issue_sprint_history.time_spent_seconds,
        filtered_issue_sprint_history.status,
        filtered_issue_sprint_history.story_points,
        filtered_issue_sprint_history.story_point_estimate 
    from filtered_issue_sprint_history
),

issue_sprint_statuses as (

    select 
        issue_sprint_daily_history.*,
        case when date_day >= cast(sprint_started_at as date) 
            and (sprint_ended_at is null or date_day <= cast(sprint_ended_at as date)) 
            then true else false 
        end as is_sprint_active,
        case when sprint_completed_at is not null 
            and date_day >= cast(sprint_completed_at as date) 
            then true else false 
        end as is_sprint_completed,
        case when date_day >= cast(issue_created_at as date) 
            and issue_resolved_at is null 
            then true else false 
        end as is_issue_open,
        case when date_day >= cast(issue_resolved_at as date) 
            and issue_resolved_at <= sprint_ended_at 
            then true else false 
        end as is_issue_resolved_in_sprint,
        case when date_day >= cast(sprint_started_at as date) 
            and date_day <= cast(sprint_ended_at as date)
            then {{ dbt.datediff('date_day', 'sprint_ended_at', 'day') }} else null 
        end as days_left_in_sprint
    from issue_sprint_daily_history
),

surrogate_key as (
    
    select *,
        {{ dbt_utils.generate_surrogate_key(['date_day','sprint_id','issue_id']) }} as sprint_issue_day_id
    from issue_sprint_statuses
) 

select *
from surrogate_key