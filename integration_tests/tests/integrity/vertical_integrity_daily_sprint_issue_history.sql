{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
    and var('jira_using_sprints', true)
) }}

with end_model as (

    select
        sprint_id,
        issue_id,
        sprint_started_at,
        min(date_day) as first_date_end
    from {{ ref('jira__daily_sprint_issue_history') }}
    group by 1,2,3
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

-- For each issue on each day, find the timestamp of the last sprint-related event.
-- This mirrors how jira__daily_issue_field_history forward-fills using the end-of-day state.
last_sprint_event_per_day as (

    select
        issue_multiselect_history.issue_id,
        cast(issue_multiselect_history.updated_at as date) as updated_date,
        max(issue_multiselect_history.updated_at) as last_updated_at
    from issue_multiselect_history
    inner join field
        on field.field_id = issue_multiselect_history.field_id
    where lower(field.field_name) = 'sprint'
    group by 1, 2
),

-- Only include sprint IDs that were recorded at the last event timestamp for that issue/day.
-- Sprints that appeared earlier in the day but were superseded are excluded.
issue_sprint_fields as (

    select
        issue_multiselect_history.issue_id,
        cast(issue_multiselect_history.field_value as {{ dbt.type_int() }}) as sprint_id,
        last_sprint_event_per_day.updated_date
    from issue_multiselect_history
    inner join field
        on field.field_id = issue_multiselect_history.field_id
    inner join last_sprint_event_per_day
        on issue_multiselect_history.issue_id = last_sprint_event_per_day.issue_id
        and cast(issue_multiselect_history.updated_at as date) = last_sprint_event_per_day.updated_date
        and issue_multiselect_history.updated_at = last_sprint_event_per_day.last_updated_at
    where lower(field.field_name) = 'sprint'
        and issue_multiselect_history.field_value is not null
),


source_model as (

    select
        issue_id,
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
full outer join source_model
    on end_model.sprint_id = cast(source_model.sprint_id as string)
    and end_model.issue_id = source_model.issue_id
where first_date_source != first_date_end
and first_date_source >= cast(sprint_started_at as date)
