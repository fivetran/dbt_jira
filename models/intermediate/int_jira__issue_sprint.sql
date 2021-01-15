{{ config(enabled=var('jira_using_sprints', True)) }}

with sprint as (

    select * 
    from {{ var('sprint') }}

),

field_history as (

     -- sprints don't appear to be capable of multiselect in the UI...
    select *
    from {{ ref('int_jira__issue_multiselect_history') }}

),

-- only grab history pertaining to sprints
sprint_field_history as (

    select 
        field_history.*,
        row_number() over (
                    partition by issue_id order by updated_at desc
                    ) as row_num

    from field_history
    where lower(field_name) = 'sprint'

),

last_sprint as (
  
    select *
    from sprint_field_history
    
    where row_num = 1

),

sprint_rollovers as (

    select 
        issue_id,
        count(distinct case when field_value is not null then field_value end) as count_sprint_changes
    
    from sprint_field_history
    group by 1

),

issue_sprint as (

    select 
        last_sprint.issue_id,
        last_sprint.field_value as sprint_id,
        sprint.sprint_name,
        sprint.board_id,
        sprint.started_at as sprint_started_at,
        sprint.ended_at as sprint_ended_at,
        sprint.completed_at as sprint_completed_at,
        coalesce(sprint_rollovers.count_sprint_changes, 0) as count_sprint_changes

    from 
    last_sprint 
    join sprint on last_sprint.field_value = cast(sprint.sprint_id as {{dbt_utils.type_string()}})
    left join sprint_rollovers on sprint_rollovers.issue_id = last_sprint.issue_id
    
)

select * from issue_sprint