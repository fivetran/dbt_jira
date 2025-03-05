{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with end_model as (

    select 
        sprint_id, 
        issues_assigned_to_sprint as issues_in_sprint_end
    from {{ ref('jira__sprint_enhanced') }}
),


issue_multiselect_history as (

    select *
    from {{ ref('stg_jira__issue_multiselect_history') }}
),

field as (

    select *
    from {{ ref('stg_jira__field') }}
),

sprint as (

    select *
    from {{ ref('stg_jira__sprint') }}
),

issue_sprint_fields as (

    select 
        issue_multiselect_history.issue_id, 
        issue_multiselect_history.field_value, 
        field.field_name
    from issue_multiselect_history
    inner join field
        on field.field_id = issue_multiselect_history.field_id
    where lower(field.field_name) = 'sprint'
),

source_model as (

    select 
        sprint.sprint_id, 
        count(distinct issue_id) as issues_in_sprint_source
    from issue_sprint_fields
    inner join sprint
        on issue_sprint_fields.field_value = cast(sprint.sprint_id as string)
    group by 1
)

select 
    end_model.sprint_id,
    issues_in_sprint_end,
    issues_in_sprint_source
from end_model
join source_model
    on end_model.sprint_id = source_model.sprint_id
where issues_in_sprint_end != issues_in_sprint_source 