{{ config( materialized='table') }}

{%- set issue_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_daily_field_history')) -%}

with change_data as (

    select *
    from {{ ref('int_jira__pivot_daily_field_history') }}

), fill_values as (

    select 
        valid_starting_on, 
        issue_id,
        issue_day_id
        
        {% for col in issue_columns if col.name|lower not in ['valid_starting_on','issue_id','issue_day_id'] %} 
        
        ,last_value({{ col.name }} ignore nulls) over 
          (partition by issue_id order by valid_starting_on asc rows between unbounded preceding and current row) as {{ col.name }}

        {% endfor %}

    from change_data

)

select *
from fill_values