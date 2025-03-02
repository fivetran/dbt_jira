with field_history as (
    select *
    from {{ ref('int_jira__issue_field_history') }}  
    where lower(field_name) like '%story point%'
),

-- Assign row_number() early for both Story Points and Story Point Estimate
ranked_story_points as (
    select 
        issue_id,
        field_name,
        field_value,
        updated_at,
        row_number() over (partition by issue_id, lower(field_name) order by updated_at desc) as row_num
    from field_history
),

-- Get Latest Story Points
last_story_points as (
    select issue_id, field_value as current_story_points
    from ranked_story_points
    where lower(field_name) like '%story points%'
      and row_num = 1
),

-- Get Latest Story Point Estimate
last_story_point_estimate as (
    select issue_id, field_value as current_estimated_story_points
    from ranked_story_points
    where lower(field_name) like '%story point estimate%'
      and row_num = 1
),

-- Count Changes for Each Field
sp_changes as (
    select 
        issue_id,
        count(distinct case when lower(field_name) like '%story points%' and field_value is not null then field_value end) 
            as count_sp_changes,
        count(distinct case when lower(field_name) like '%story point estimate%' and field_value is not null then field_value end) 
            as count_estimated_sp_changes   
    from field_history
    group by issue_id
),

-- Merge Results
issue_story_points as (
    select 
        coalesce(sp.issue_id, spe.issue_id) as issue_id,
        cast(sp.current_story_points as {{ dbt.type_float() }}) as current_story_points,
        cast(spe.current_story_points_estimate as {{ dbt.type_float() }}) as current_estimated_story_points,
        cast(spc.count_sp_changes as {{ dbt.type_int() }}) as count_sp_changes,
        cast(spc.count_estimated_sp_changes as {{ dbt.type_int() }}) as count_estimated_sp_changes
    from last_story_points sp
    full outer join last_story_point_estimate spe on sp.issue_id = spe.issue_id
    left join sp_changes spc on coalesce(sp.issue_id, spe.issue_id) = spc.issue_id
)

select * 
from issue_story_points
