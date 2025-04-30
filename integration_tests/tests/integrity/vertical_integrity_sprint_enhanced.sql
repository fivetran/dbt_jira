{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
    and var('jira_using_sprints', true)
) }}

with end_model as (

    select 
        sprint_id, 
        sprint_issues as sprint_issues_end
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
        count(distinct issue_id) as sprint_issues_source
    from issue_sprint_fields
    inner join sprint
        on issue_sprint_fields.field_value = cast(sprint.sprint_id as string)
    group by 1
)

select 
    end_model.sprint_id,
    sprint_issues_source,
    sprint_issues_end
from end_model
full outer join source_model
    on end_model.sprint_id = source_model.sprint_id
where sprint_issues_source != sprint_issues_end 