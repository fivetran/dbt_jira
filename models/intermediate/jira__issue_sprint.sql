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
    from {{ var('issue_field_history') }}
    
),

last_sprint as (

    select
        field_history.issue_id,
        last_value(field_history.value respect nulls) over(partition by issue_id order by updated_at asc) as sprint_id

    from field_history
    join sprint_field using (field_id)
),

issue_sprint as (

    select 
        last_sprint.issue_id,
        last_sprint.sprint_id,
        last_sprint.sprint_name,
        last_sprint.board_id,
        last_sprint.started_at as sprint_started_at,
        last_sprint.ended_at as sprint_ended_at
        last_sprint.completed_at as sprint_completed_at

    from 
    last_sprint join sprint using (sprint_id)
    
)

select * from issue_sprint