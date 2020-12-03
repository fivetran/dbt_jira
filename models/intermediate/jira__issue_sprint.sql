with sprint as (

    select * 
    from {{ var('sprint') }}

),

sprint_field as (

    select field_id
        
    from {{ var('field') }}
    where lower(field_name) = 'sprint'
),

field_history as (

    select *
    from {{ var('issue_multiselect_history') }}
    -- sprint is for some reason an array...
    -- todo: maybe get how many times it's been rolled over
),

sprint_field_history as (

    select 
        field_history.*,
        first_value(field_history.field_value)

    from field_history
    join sprint_field using(field_id)

),

sprint_rollovers as (

    select 
        issue_id,
        count(distinct case when field_value is not null then field_value end) as n_sprints
    
    from sprint_field_history
    group by 1
),

last_sprint as (

    select
        sprint_field_history.issue_id,
        last_value(sprint_field_history.field_value respect nulls) over(partition by issue_id order by updated_at asc) as sprint_id

    from sprint_field_history
    join sprint_field using (field_id)
),

issue_sprint as (

    select 
        last_sprint.issue_id,
        last_sprint.sprint_id,
        last_sprint.sprint_name,
        last_sprint.board_id,
        last_sprint.started_at as sprint_started_at,
        last_sprint.ended_at as sprint_ended_at,
        last_sprint.completed_at as sprint_completed_at

    from 
    last_sprint 
    join sprint on last_sprint.sprint_id = sprint.sprint_id
    join sprint_rollovers on sprint_rollovers.sprint_id = sprint.sprint_id
    
)

select * from issue_sprint