{{ config(enabled=var('jira_using_sprints', True)) }}

with field_history as (

    select
        issue_id,
        lower(field_name) as field_name,
        field_value,
        updated_at
    from {{ ref('int_jira__issue_field_history') }}
    where lower(field_name) like '%story point%'
),

issue_sprint_history as (

    select distinct
        issue_id,
        sprint_id,
        sprint_started_at,
        sprint_ended_at
    from {{ ref('int_jira__issue_sprint') }}  -- Replace with actual sprint history model reference
),

-- Get first and last values for "story points"
ranked_start_story_points as (

    select
        issue_sprint_history.issue_id,
        issue_sprint_history.sprint_id,
        issue_sprint_history.sprint_started_at,
        cast(field_history.field_value as {{ dbt.type_float() }}) as story_points_start,
        row_number() over (
            partition by issue_sprint_history.issue_id, issue_sprint_history.sprint_id
            order by field_history.updated_at asc
        ) as row_number
    from issue_sprint_history
    left join field_history
        on issue_sprint_history.issue_id = field_history.issue_id
        and lower(field_history.field_name) like '%story points%'
        and field_history.updated_at <= issue_sprint_history.sprint_started_at
),

ranked_end_story_points as (

    select
        issue_sprint_history.issue_id,
        issue_sprint_history.sprint_id,
        issue_sprint_history.sprint_ended_at,
        cast(field_history.field_value as {{ dbt.type_float() }})  as story_points_end,
        row_number() over (
            partition by issue_sprint_history.issue_id, issue_sprint_history.sprint_id
            order by field_history.updated_at desc
        ) as row_number
    from issue_sprint_history
    left join field_history
        on issue_sprint_history.issue_id = field_history.issue_id
        and lower(field_history.field_name) like '%story points%'
        and field_history.updated_at <= issue_sprint_history.sprint_ended_at
),

first_story_points as (

    select 
        issue_id, 
        sprint_id, 
        story_points_start
    from ranked_start_story_points
    where row_number = 1
),

last_story_points as (

    select
        issue_id, 
        sprint_id,
        story_points_end
    from ranked_end_story_points
    where row_number = 1
),

-- Get first and last values for "story point estimate"
ranked_start_story_point_estimate as (

    select
        issue_sprint_history.issue_id,
        issue_sprint_history.sprint_id,
        issue_sprint_history.sprint_started_at,
        cast(field_history.field_value as {{ dbt.type_float() }})  as story_point_estimate_start,
        row_number() over (
            partition by issue_sprint_history.issue_id, issue_sprint_history.sprint_id
            order by field_history.updated_at asc
        ) as row_number
    from issue_sprint_history
    left join field_history
        on issue_sprint_history.issue_id = field_history.issue_id
        and lower(field_history.field_name) like '%story point estimate%'
        and field_history.updated_at <= issue_sprint_history.sprint_started_at
),

ranked_end_story_point_estimate as (

    select
        issue_sprint_history.issue_id,
        issue_sprint_history.sprint_id,
        issue_sprint_history.sprint_ended_at,
        cast(field_history.field_value as {{ dbt.type_float() }}) as story_point_estimate_end,
        row_number() over (
            partition by issue_sprint_history.issue_id, issue_sprint_history.sprint_id
            order by field_history.updated_at desc
        ) as row_number
    from issue_sprint_history
    left join field_history
        on issue_sprint_history.issue_id = field_history.issue_id
        and lower(field_history.field_name) like '%story point estimate%'
        and field_history.updated_at <= issue_sprint_history.sprint_ended_at
),

first_story_point_estimate as (

    select 
        issue_id,
        sprint_id, 
        story_point_estimate_start
    from ranked_start_story_point_estimate
    where row_number = 1
),

last_story_point_estimate as (

    select 
        issue_id,
        sprint_id, 
        story_point_estimate_end
    from ranked_end_story_point_estimate
    where row_number = 1
),

sprint_story_point_history as (

    select 
        issue_sprint_history.issue_id,
        issue_sprint_history.sprint_id,
        coalesce(first_story_points.story_points_start, 0) as story_points_start,  
        coalesce(last_story_points.story_points_end, first_story_points.story_points_start, 0) as story_points_end,  
        coalesce(first_story_point_estimate.story_point_estimate_start, 0) as story_point_estimate_start,  
        coalesce(last_story_point_estimate.story_point_estimate_end, first_story_point_estimate.story_point_estimate_start, 0) as story_point_estimate_end
    from issue_sprint_history
    left join first_story_points
        on issue_sprint_history.issue_id = first_story_points.issue_id
        and issue_sprint_history.sprint_id = first_story_points.sprint_id
    left join last_story_points
        on issue_sprint_history.issue_id = last_story_points.issue_id
        and issue_sprint_history.sprint_id = last_story_points.sprint_id
    left join first_story_point_estimate
        on issue_sprint_history.issue_id = first_story_point_estimate.issue_id
        and issue_sprint_history.sprint_id = first_story_point_estimate.sprint_id
    left join last_story_point_estimate
        on issue_sprint_history.issue_id = last_story_point_estimate.issue_id
        and issue_sprint_history.sprint_id = last_story_point_estimate.sprint_id
),

sprint_history_metrics as (

    select         
        sprint_id,
        count(distinct issue_id) as issues_assigned_to_sprint,
        sum(story_points_start) as initial_story_points,
        sum(story_point_estimate_start) as initial_story_points_estimate,
        sum(story_points_end) as final_story_points,
        sum(story_point_estimate_end) as final_story_points_estimate
    from sprint_story_point_history
    {{ dbt_utils.group_by(1) }}
)

select *
from sprint_history_metrics