{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with end_model as (

    select 
        sprint_id, 
        issue_id,
        min(date_day) as first_date_end
    from {{ ref('jira__daily_sprint_issue_history') }}
    group by 1,2
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
        distinct issue_multiselect_history.issue_id, 
        cast(issue_multiselect_history.field_value as int64) as sprint_id,  
        cast(issue_multiselect_history.updated_at as date) as updated_date
    from issue_multiselect_history
    inner join field
        on field.field_id = issue_multiselect_history.field_id
    where lower(field.field_name) = 'sprint'
        and field_value is not null
),


source_model as (

    select issue_id,
        sprint_id,
        min(updated_date) as first_date_source
    from issue_sprint_fields 
    group by 1, 2
)

select 
    end_model.sprint_id,
    end_model.issue_id,
    first_date_source,
    first_date_end
from end_model
join source_model
    on end_model.sprint_id = source_model.sprint_id
    and end_model.issue_id = source_model.issue_id
where first_date_source != first_date_end 