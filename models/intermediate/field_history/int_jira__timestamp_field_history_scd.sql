{{ config(materialized='table') }}

{%- set timestamp_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_timestamp_field_history')) -%}

with change_data as (

    select *
    from {{ ref('int_jira__pivot_timestamp_field_history') }}

), set_values as (
    -- Create partitions to group consecutive null values for forward-filling
    select
        updated_at,
        issue_id,
        updated_at_week,
        author_id,
        status,
        sum( case when status is null then 0 else 1 end) over ( partition by issue_id
            order by updated_at rows unbounded preceding) as status_field_partition

        {% for col in timestamp_columns if col.name|lower not in ['updated_at','issue_id','updated_at_week','status', 'author_id'] %}
        , {{ col.name }}
        -- create a batch/partition once a new value is provided
        , sum( case when {{ col.name }} is null then 0 else 1 end) over ( partition by issue_id
            order by updated_at rows unbounded preceding) as {{ col.name }}_field_partition

        {% endfor %}

    from change_data

), fill_values as (
    -- Forward-fill values within each partition to create SCD Type 2 records
    select
        updated_at,
        issue_id,
        updated_at_week,
        author_id,
        first_value( status ) over (
            partition by issue_id, status_field_partition
            order by updated_at asc rows between unbounded preceding and current row) as status

        {% for col in timestamp_columns if col.name|lower not in ['updated_at','issue_id','updated_at_week','status', 'author_id'] %}

        -- grab the value that started this batch/partition
        , first_value( {{ col.name }} ) over (
            partition by issue_id, {{ col.name }}_field_partition
            order by updated_at asc rows between unbounded preceding and current row) as {{ col.name }}

        {% endfor %}

    from set_values

)

select *
from fill_values