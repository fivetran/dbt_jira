{{ config( materialized='table') }}

{%- set issue_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_daily_field_history')) -%}
{#- Dedupe: dbt v2 on Databricks returns a partitioned table's partition column twice. -#}
{%- set issue_column_names = [] -%}
{%- set seen_column_names = [] -%}
{%- for col in issue_columns -%}
    {%- set col_name_lower = col.name|lower -%}
    {%- if col_name_lower not in ['valid_starting_on','issue_id','issue_day_id','source_relation'] and col_name_lower not in seen_column_names -%}
        {%- do issue_column_names.append(col.name) -%}
        {%- do seen_column_names.append(col_name_lower) -%}
    {%- endif -%}
{%- endfor -%}

with change_data as (

    select *
    from {{ ref('int_jira__pivot_daily_field_history') }}

), set_values as (

    select
        valid_starting_on,
        issue_id,
        source_relation,
        issue_day_id,
        status as status_id,
        sum( case when status is null then 0 else 1 end) over ( partition by issue_id {{ fivetran_utils.partition_by_source_relation(package_name='jira') }}
            order by valid_starting_on rows unbounded preceding) as status_id_field_partition

        {% for col_name in issue_column_names %}
        , {{ col_name }}
        -- create a batch/partition once a new value is provided
        , sum( case when {{ col_name }} is null then 0 else 1 end) over ( partition by issue_id {{ fivetran_utils.partition_by_source_relation(package_name='jira') }}
            order by valid_starting_on rows unbounded preceding) as {{ col_name }}_field_partition

        {% endfor %}

    from change_data

), fill_values as (

-- each row of the pivoted table includes field values if that field was updated on that day
-- we need to backfill to persist values that have been previously updated and are still valid
    select
        valid_starting_on,
        issue_id,
        source_relation,
        issue_day_id,
        first_value( status ) over (
            partition by issue_id, status_id_field_partition {{ fivetran_utils.partition_by_source_relation(package_name='jira') }}
            order by valid_starting_on asc rows between unbounded preceding and current row) as status_id

        {% for col_name in issue_column_names %}

        -- grab the value that started this batch/partition
        , first_value( {{ col_name }} ) over (
            partition by issue_id, {{ col_name }}_field_partition {{ fivetran_utils.partition_by_source_relation(package_name='jira') }}
            order by valid_starting_on asc rows between unbounded preceding and current row) as {{ col_name }}

        {% endfor %}

    from set_values

)

select *
from fill_values