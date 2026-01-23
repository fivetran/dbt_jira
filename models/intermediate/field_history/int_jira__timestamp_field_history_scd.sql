{%- set custom_columns = [] -%}
{%- for col in var('issue_field_history_columns', []) -%}
    {%- set clean_col = dbt_utils.slugify(col) | replace(' ', '_') | lower -%}
    {%- if clean_col not in ['sprint', 'story_points', 'story_point_estimate'] -%}
        {%- do custom_columns.append(clean_col) -%}
    {%- endif -%}
{%- endfor -%} 

with change_data as (

    select *
    from {{ ref('int_jira__pivot_timestamp_field_history') }}

), set_values as (
    -- Create partitions to group consecutive null values for forward-filling
    select
        updated_at,
        issue_id,
        source_relation,
        updated_at_week,
        author_id,
        status,
        sum( case when status is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at rows unbounded preceding) as status_field_partition
        , sprint
        , sum( case when sprint is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at rows unbounded preceding) as sprint_field_partition
        , story_points
        , sum( case when story_points is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at rows unbounded preceding) as story_points_field_partition
        , story_point_estimate
        , sum( case when story_point_estimate is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at rows unbounded preceding) as story_point_estimate_field_partition

        {% for col in custom_columns %}
        , {{ col }}
        -- create a batch/partition once a new value is provided
        , sum( case when {{ col }} is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at rows unbounded preceding) as {{ col }}_field_partition
        {% endfor %}

    from change_data

), fill_values as (
    -- Forward-fill values within each partition to create SCD Type 2 records
    select
        updated_at,
        issue_id,
        source_relation,
        updated_at_week,
        author_id,
        first_value( status ) over (
            partition by issue_id, status_field_partition {{ jira.partition_by_source_relation() }}
            order by updated_at asc rows between unbounded preceding and current row) as status
        , first_value( sprint ) over (
            partition by issue_id, sprint_field_partition {{ jira.partition_by_source_relation() }}
            order by updated_at asc rows between unbounded preceding and current row) as sprint
        , first_value( story_points ) over (
            partition by issue_id, story_points_field_partition {{ jira.partition_by_source_relation() }}
            order by updated_at asc rows between unbounded preceding and current row) as story_points
        , first_value( story_point_estimate ) over (
            partition by issue_id, story_point_estimate_field_partition {{ jira.partition_by_source_relation() }}
            order by updated_at asc rows between unbounded preceding and current row) as story_point_estimate

        {% for col in custom_columns %}
        -- grab the value that started this batch/partition
        , first_value( {{ col }} ) over (
            partition by issue_id, {{ col }}_field_partition {{ jira.partition_by_source_relation() }}
            order by updated_at asc rows between unbounded preceding and current row) as {{ col }}
        {% endfor %}

    from set_values

)

select *
from fill_values