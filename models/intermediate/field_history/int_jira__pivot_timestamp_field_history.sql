with issue_field_history as (

    select *
    from {{ ref('int_jira__issue_field_history') }}
),

issue_multiselect_history as (

    select *
    from {{ ref('int_jira__issue_multiselect_history') }}
),

issue_multiselect_batch_history as (
    -- Aggregate multiselect field values into comma-separated strings
    select
        field_id,
        field_name,
        issue_id,
        source_relation,
        updated_at,
        author_id,
        {{ fivetran_utils.string_agg('field_value', "', '") }} as field_values

    from issue_multiselect_history
    {{ dbt_utils.group_by(6) }}
),

combine_field_history as (
    -- Union single-select and multiselect field histories
    select
        field_id,
        issue_id,
        source_relation,
        updated_at,
        author_id,
        field_value,
        field_name
    from issue_field_history

    union all

    select
        field_id,
        issue_id,
        source_relation,
        updated_at,
        author_id,
        field_values as field_value,
        field_name
    from issue_multiselect_batch_history
),

limit_to_relevant_fields as (
    -- Filter to only status and configured custom fields
    select
        combine_field_history.*
    from combine_field_history
    where lower(field_id) = 'status'
        {%- for col in var('issue_field_history_columns', []) -%}
        or lower(field_name) = '{{ (col|lower) }}'
        {%- endfor -%}
),

int_jira__timestamp_field_history as (
    -- Convert null values to '-is_null' for consistent partitioning
    select
        field_id,
        issue_id,
        source_relation,
        field_name,
        case when field_value is null then '-is_null' else field_value end as field_value,
        updated_at,
        author_id
    from limit_to_relevant_fields
),

final as (
    -- Pivot field values into columns grouped by timestamp
    select
        updated_at,
        issue_id,
        source_relation,
        cast({{ dbt.date_trunc('week', 'updated_at') }} as date) as updated_at_week,
        author_id,
        max(case when lower(field_id) = 'status' then field_value end) as status

        {% for col in var('issue_field_history_columns', []) -%}
        , max(case when lower(field_name) = '{{ col|lower }}' then field_value end)
            as {{ dbt_utils.slugify(col) | replace(' ', '_') | lower }}
        {% endfor -%}

    from int_jira__timestamp_field_history
    {{ dbt_utils.group_by(5) }}
)

select *
from final