
{%- set pivot_data_columns = adapter.get_columns_in_relation(ref('int_jira__pivot_daily_field_history')) -%}

with pivoted_daily_history as (

    select * 
    from {{ ref('int_jira__pivot_daily_field_history') }}
),

calendar as (

    select *
    from {{ ref('int_jira__issue_calendar_spine') }}
),

joined as (

    select
        calendar.date_day,
        calendar.issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','valid_starting_on'] %}  -- todo: add surrogate key after making it
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
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','valid_starting_on'] %}  -- todo: add surrogate key after making it
        , last_value({{ col.name }} ignore nulls) over 
          (partition by issue_id order by date_day asc rows between unbounded preceding and current row) as {{ col.name }}
        {% endfor %}

    from joined
),

fix_null_values as (

    select  
        date_day,
        issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','valid_starting_on'] %}  -- todo: add surrogate key after making it
        , case when {{ col.name }} = 'is_null' then null else {{ col.name }} end as {{ col.name }}
        {% endfor %}

    from fill_values

)

select *
from fix_null_values