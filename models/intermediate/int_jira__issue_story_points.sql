with field_history as (

    select
        issue_id,
        lower(field_name) as field_name,
        field_value,
        updated_at,
        row_number() over (partition by issue_id, lower(field_name) order by updated_at desc) as row_num
    from {{ ref('int_jira__issue_field_history') }}  
    where lower(field_name) like '%story point%'
),

-- Get Latest Story Points
latest_story_points as (

    select 
        issue_id, 
        field_value as current_story_points
    from field_history
    where lower(field_name) like '%story points%' 
    and row_num = 1
),

-- Get Latest Story Point Estimate
latest_story_point_estimate as (

    select 
        issue_id, 
        field_value as current_estimated_story_points
    from field_history
    where lower(field_name) like '%story point estimate%' 
    and row_num = 1
),

-- Count Changes for Story Points and Story Point Estimates
story_point_changes as (

    select 
        cast(issue_id as {{ dbt.type_int() }}) as issue_id,
        count(distinct case when lower(field_name) like '%story points%' and field_value is not null then field_value end) 
            as count_story_point_changes,
        count(distinct case when lower(field_name) like '%story point estimate%' and field_value is not null then field_value end) 
            as count_story_point_estimate_changes
    from field_history
    {{ dbt_utils.group_by(1) }}
),

-- Merge Results Without Fanout
issue_story_points as (

    select 
        coalesce(latest_story_points.issue_id, latest_story_point_estimate.issue_id) as issue_id,
        cast(latest_story_points.current_story_points as {{ dbt.type_float() }}) as current_story_points,
        cast(latest_story_point_estimate.current_estimated_story_points as {{ dbt.type_float() }}) as current_estimated_story_points,
        cast(story_point_changes.count_story_point_changes as {{ dbt.type_int() }}) as count_sp_changes,
        cast(story_point_changes.count_story_point_estimate_changes as {{ dbt.type_int() }}) as count_estimated_sp_changes
    from latest_story_points
    full outer join latest_story_point_estimate 
        on latest_story_points.issue_id = latest_story_point_estimate.issue_id
    left join story_point_changes 
        on coalesce(latest_story_points.issue_id, latest_story_point_estimate.issue_id) = story_point_changes.issue_id
)

select * 
from issue_story_points
