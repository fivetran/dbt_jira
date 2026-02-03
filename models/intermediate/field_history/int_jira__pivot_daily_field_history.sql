{{
    config(
        materialized='incremental' if jira_is_incremental_compatible() else 'table',
        partition_by = {'field': 'valid_starting_at_week', 'data_type': 'date'}
            if target.type not in ['spark','databricks'] else ['valid_starting_at_week'],
        cluster_by = ['valid_starting_at_week'],
        unique_key='issue_day_id',
        incremental_strategy = 'insert_overwrite' if target.type in ('bigquery', 'databricks', 'spark') else 'delete+insert',
        file_format='delta'
    )
}}

-- issue_multiselect_history splits out an array-type field into multiple rows with unique individual values
-- to combine with issue_field_history we need to aggregate the multiselect field values.

-- Hardcode 'team' into the issue_field_history_columns list if not already present
{% set issue_field_history_columns = var('issue_field_history_columns', []) %}
{% do issue_field_history_columns.append('team') if var('jira_using_teams', True) 
    and 'team' not in issue_field_history_columns | map('lower') | list %}

with issue_field_history as (

    select *

    from {{ ref('int_jira__issue_field_history') }}

    {% if is_incremental() %}
    {% set max_valid_starting_at_week = jira.jira_lookback(from_date='max(valid_starting_on)', datepart='week', interval=var('lookback_window', 1)) %}
    where cast(updated_at as date) >= {{ max_valid_starting_at_week }}
    {% endif %}
),

issue_multiselect_history as (

    select *

    from {{ ref('int_jira__issue_multiselect_history') }}

    {% if is_incremental() %}
    where cast(updated_at as date) >= {{ max_valid_starting_at_week }}
    {% endif %}
),

{% if var('jira_using_sprints', True) %}
sprints as (

    select *
    from {{ ref('stg_jira__sprint') }}
),

sprint_name_multiselect_history as (
    -- Create synthetic sprint_name rows by resolving sprint IDs to names
    select
        'sprint_field' as field_id,
        'sprint_name' as field_name,
        issue_multiselect_history.issue_id,
        issue_multiselect_history.source_relation,
        issue_multiselect_history.updated_at,
        cast({{ dbt.date_trunc('day', 'issue_multiselect_history.updated_at') }} as date) as date_day,
        coalesce(sprints.sprint_name, issue_multiselect_history.field_value) as field_value

    from issue_multiselect_history

    left join sprints
        on cast(sprints.sprint_id as {{ dbt.type_string() }}) = issue_multiselect_history.field_value
        and sprints.source_relation = issue_multiselect_history.source_relation

    where lower(issue_multiselect_history.field_name) = 'sprint'
),
{% endif %}

combined_multiselect_history as (
    -- Union original multiselect fields (IDs) with synthetic sprint_name field
    select
        field_id,
        field_name,
        issue_id,
        source_relation,
        updated_at,
        cast({{ dbt.date_trunc('day', 'updated_at') }} as date) as date_day,
        field_value
    from issue_multiselect_history

    {% if var('jira_using_sprints', True) %}
    union all

    select
        field_id,
        field_name,
        issue_id,
        source_relation,
        updated_at,
        date_day,
        field_value
    from sprint_name_multiselect_history
    {% endif %}
),

issue_multiselect_batch_history as (

    select
        field_id,
        field_name,
        issue_id,
        source_relation,
        updated_at,
        date_day,
        {{ fivetran_utils.string_agg('field_value', "', '") }} as field_values

    from combined_multiselect_history

    {{ dbt_utils.group_by(6) }}
),

combine_field_history as (
-- combining all the field histories together
    select
        field_id,
        issue_id,
        source_relation,
        updated_at,
        field_value,
        field_name

    from issue_field_history

    union all

    select
        field_id,
        issue_id,
        source_relation,
        updated_at,
        field_values as field_value, -- this is an aggregated list but we'll just call it field_value
        field_name

    from issue_multiselect_batch_history
),

get_valid_dates as (

    select
        field_id,
        issue_id,
        source_relation,
        field_value,
        field_name,
        updated_at as valid_starting_at,

        -- this value is valid until the next value is updated
        lead(updated_at, 1) over(partition by issue_id, {{ var('jira_field_grain', 'field_id') }} {{ jira.partition_by_source_relation() }} order by updated_at asc) as valid_ending_at,
        cast( {{ dbt.date_trunc('day', 'updated_at') }} as date) as valid_starting_on

    from combine_field_history
),

limit_to_relevant_fields as (
    -- let's remove unnecessary rows moving forward and grab field names
    select
        get_valid_dates.*

    from get_valid_dates

    where lower(field_id) = 'status'
        or lower(field_name) in ('sprint', 'sprint_name', 'story points', 'story point estimate'
        {%- for col in issue_field_history_columns -%}
            ,'{{ (col|lower) }}'
        {%- endfor -%} )
),

order_daily_values as (

    select
        *,
        -- want to grab last value for an issue's field for each day
        row_number() over (
            partition by valid_starting_on, issue_id, {{ var('jira_field_grain', 'field_id') }} {{ jira.partition_by_source_relation() }}
            order by valid_starting_at desc
            ) as row_num

    from limit_to_relevant_fields
),

-- only looking at the latest value for each day
get_latest_daily_value as (

    select * 

    from order_daily_values
    where row_num = 1
), 

int_jira__daily_field_history as (

    select
        field_id,
        issue_id,
        source_relation,
        field_name,

        -- doing this to figure out what values are actually null and what needs to be backfilled in jira__daily_issue_field_history
        case when field_value is null then '-is_null' else field_value end as field_value,
        valid_starting_at,
        valid_ending_at,
        valid_starting_on

    from get_latest_daily_value
),

pivot_out as (

    -- pivot out default columns (status and sprint) and others specified in the var(issue_field_history_columns)
    -- only days on which a field value was actively changed will have a non-null value. the nulls will need to
    -- be backfilled in the final jira__daily_issue_field_history model
    select
        valid_starting_on,
        issue_id,
        source_relation,
        cast({{ dbt.date_trunc('week', 'valid_starting_at') }} as date) as valid_starting_at_week,
        max(case when lower(field_id) = 'status' then field_value end) as status,
        max(case when lower(field_name) = 'sprint' then field_value end) as sprint,
        max(case when lower(field_name) = 'sprint_name' then field_value end) as sprint_name,
        max(case when lower(field_name) = 'story points' then field_value end) as story_points,
        max(case when lower(field_name) = 'story point estimate' then field_value end) as story_point_estimate

        {% for col in issue_field_history_columns -%}
        {% if col|lower not in ['sprint', 'sprint_name', 'story points', 'story point estimate'] %}
            , max(case when lower(field_name) = '{{ col|lower }}' then field_value end) as {{ dbt_utils.slugify(col) | replace(' ', '_') | lower }}
        {% endif %}
        {% endfor -%}

    from int_jira__daily_field_history

    {{ dbt_utils.group_by(4) }}
),

final as (
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['valid_starting_on','issue_id','source_relation']) }} as issue_day_id

    from pivot_out
)

select *
from final 
