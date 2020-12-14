{{
    config(
        materialized='incremental',
        partition_by = {'field': 'date_day', 'data_type': 'date'},
        unique_key='issue_day_id'
    )
}}

-- grab column names that were pivoted out
{%- set pivot_data_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_daily_field_history')) -%}

with pivoted_daily_history as (

    select * 
    from {{ ref('int_jira__pivot_daily_field_history') }}

    {% if is_incremental() %}
    where valid_starting_on >= (select max(date_day) from {{ this }} )
    {% endif %}

),

calendar as (

    select *
    from {{ ref('int_jira__issue_calendar_spine') }}

    {% if is_incremental() %}
    where date_day >= (select max(date_day) from {{ this }} )
    {% endif %}
),

joined as (

    select
        calendar.date_day,
        calendar.issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_day_id','issue_id','valid_starting_on'] %}  -- todo: add surrogate key after making it
        , {{ col.name }}
        {% endfor %}

    from calendar
    left join pivoted_daily_history 
        on calendar.issue_id=pivoted_daily_history.issue_id
        and calendar.date_day=pivoted_daily_history.valid_starting_on
),

fill_values as (

    select  
        date_day,
        issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %}
        , last_value({{ col.name }} ignore nulls) over 
          (partition by issue_id order by date_day asc rows between unbounded preceding and current row) as {{ col.name }}
        {% endfor %}

    from joined
),

fix_null_values as (

    select  
        date_day,
        issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %} 
        , case when {{ col.name }} = 'is_null' then null else {{ col.name }} end as {{ col.name }}
        {% endfor %}

    from fill_values

),

surrogate_key as (

    select
        *,
        {{ dbt_utils.surrogate_key(['date_day','issue_id']) }} as issue_day_id

    from fix_null_values
)

select *
from surrogate_key