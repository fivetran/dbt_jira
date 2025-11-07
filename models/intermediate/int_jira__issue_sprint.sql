{{ config(enabled=var('jira_using_sprints', True)) }}

with sprint as (

    select * 
    from {{ ref('stg_jira__sprint') }}
),

field_history as (

    -- sprints don't appear to be capable of multiselect in the UI...
    select *
    from {{ ref('int_jira__issue_multiselect_history') }}
),

sprint_field_history as (

    select
        field_history.*,
        sprint.sprint_id,
        sprint.sprint_name,
        sprint.board_id,
        sprint.completed_at,
        sprint.ended_at,
        sprint.started_at,
        sprint._fivetran_synced,
        row_number() over (
                    partition by field_history.issue_id {{ jira.partition_by_source_relation(alias='field_history') }}
                    order by field_history.updated_at desc, sprint.started_at desc
                    ) as row_num
    from field_history
    inner join sprint
        on field_history.field_value = cast(sprint.sprint_id as {{ dbt.type_string() }})
        and field_history.source_relation = sprint.source_relation
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
        source_relation,
        count(distinct case when field_value is not null then field_value end) as count_sprint_changes
    from sprint_field_history
    group by 1, 2
),

issue_sprint as (

    select
        last_sprint.issue_id,
        last_sprint.source_relation,
        last_sprint.field_value as current_sprint_id,
        last_sprint.sprint_name as current_sprint_name,
        last_sprint.board_id,
        last_sprint.started_at as sprint_started_at,
        last_sprint.ended_at as sprint_ended_at,
        last_sprint.completed_at as sprint_completed_at,
        coalesce(sprint_rollovers.count_sprint_changes, 0) as count_sprint_changes
    from last_sprint
    left join sprint_rollovers
        on sprint_rollovers.issue_id = last_sprint.issue_id
        and sprint_rollovers.source_relation = last_sprint.source_relation
)

select *
from issue_sprint