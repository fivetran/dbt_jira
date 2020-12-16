with sprint as (

    select * 
    from {{ var('sprint') }}

),

-- sprint is technically a custom field and therefore has a custom field_id
sprint_field as (

    select field_id
        
    from {{ var('field') }}
    where lower(field_name) = 'sprint'
),

field_history as (

     -- sprints don't appear to be capable of multiselect in the UI...
    select *
    from {{ var('issue_multiselect_history') }}

),

-- only grab history pertaining to sprints
sprint_field_history as (

    select 
        field_history.*

    from field_history
    join sprint_field using(field_id)

),

sprint_rollovers as (

    select 
        issue_id,
        count(distinct case when field_value is not null then field_value end) as n_sprint_changes
    
    from sprint_field_history
    group by 1
),

last_sprint as (

    select issue_id, sprint_id 
    from (
        select
            sprint_field_history.issue_id,
            -- respecting nulls in case the issue was most recently returned to the backlog 
            cast( first_value(sprint_field_history.field_value respect nulls) over (
                partition by issue_id order by updated_at desc) as {{ dbt_utils.type_int() }} ) as sprint_id

        from sprint_field_history 
    )
    group by 1,2
),

issue_sprint as (

    select 
        last_sprint.issue_id,
        last_sprint.sprint_id,
        sprint.sprint_name,
        sprint.board_id,
        sprint.started_at as sprint_started_at,
        sprint.ended_at as sprint_ended_at,
        sprint.completed_at as sprint_completed_at,
        coalesce(sprint_rollovers.n_sprint_changes, 0) as n_sprint_changes -- todo: check if this includes the initialized null

    from 
    last_sprint 
    join sprint on last_sprint.sprint_id = sprint.sprint_id
    left join sprint_rollovers on sprint_rollovers.issue_id = last_sprint.issue_id
    
)

select * from issue_sprint