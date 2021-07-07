{{ config( materialized='table') }}

{%- set issue_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_daily_field_history')) -%}

with change_data as (

    select *
    from {{ ref('int_jira__pivot_daily_field_history') }}

), set_values as (

    select 
        valid_starting_on, 
        issue_id,
        issue_day_id

        {% for col in issue_columns if col.name|lower not in ['valid_starting_on','issue_id','issue_day_id'] %} 
        
        , sum( case when {{ col.name }} is null then 0 else 1 end) over (
            order by issue_id, valid_starting_on rows unbounded preceding) as {{ col.name }}_field_partition

        {% endfor %}

), fill_values as (

-- each row of the pivoted table includes field values if that field was updated on that day
-- we need to backfill to persist values that have been previously updated and are still valid 
    select 
        valid_starting_on, 
        issue_id,
        issue_day_id
        
        {% for col in issue_columns if col.name|lower not in ['valid_starting_on','issue_id','issue_day_id'] %} 

        ,first_value( {{ col.name }} ) over (
            partition by {{ col.name }}_field_patition 
            order by valid_starting_on asc rows between unbounded preceding and current row) as {{ col.name }}

        {% endfor %}

    from change_data

)

select *
from fill_values