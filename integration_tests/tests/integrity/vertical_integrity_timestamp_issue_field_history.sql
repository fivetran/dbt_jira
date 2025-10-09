

{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with end_model as (
    select
        issue_id,
        count(*) as timestamp_records
    from {{ ref('jira__timestamp_issue_field_history') }}
    group by 1
),

source_field_changes as (
    select
        issue_id,
        updated_at,
        field_id
    from {{ ref('stg_jira__issue_field_history') }}
    union all
    select
        issue_id,
        updated_at,
        field_id
    from {{ ref('stg_jira__issue_multiselect_history') }}
),

-- Filter to core fields that should always be tracked
relevant_fields as (
    select
        source_field_changes.issue_id,
        source_field_changes.updated_at
    from source_field_changes
    inner join {{ ref('stg_jira__field') }} as field
        on field.field_id = source_field_changes.field_id
    where lower(field.field_id) = 'status'
        or lower(field.field_name) in ('sprint', 'story points', 'story point estimate')
),

source_model as (
    select
        issue_id,
        count(distinct updated_at) as source_timestamps
    from relevant_fields
    group by 1
)

select
    coalesce(end_model.issue_id, source_model.issue_id) as issue_id,
    coalesce(timestamp_records, 0) as timestamp_records,
    coalesce(source_timestamps, 0) as source_timestamps
from end_model
full outer join source_model
    on end_model.issue_id = source_model.issue_id