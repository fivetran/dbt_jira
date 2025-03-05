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

sprint_field_history as (

    select 
        field_history.*,
        sprint.*,
        row_number() over (
                    partition by field_history.issue_id 
                    order by field_history.updated_at desc, sprint.started_at desc         
                    ) as row_num
    from field_history
    inner join sprint 
        on field_history.field_value = cast(sprint.sprint_id as {{ dbt.type_string() }})
    where lower(field_history.field_name) = 'sprint'
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
    {{ dbt_utils.group_by(1) }}
),

issue_sprint as (

    select 
        sprint_field_history.issue_id,
        sprint_field_history.field_value as sprint_id,
        sprint_field_history.sprint_name as current_sprint_name,
        sprint_field_history.board_id,
        sprint_field_history.started_at as sprint_started_at,
        sprint_field_history.ended_at as sprint_ended_at,
        sprint_field_history.completed_at as sprint_completed_at,
        sprint_field_history.row_num,
        coalesce(sprint_rollovers.count_sprint_changes, 0) as count_sprint_changes
    from sprint_field_history 
    left join sprint_rollovers on sprint_rollovers.issue_id = sprint_field_history.issue_id
)

select *
from issue_sprint