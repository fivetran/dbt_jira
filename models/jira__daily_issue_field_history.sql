{{
    config(
        materialized='incremental',
        partition_by = {'field': 'date_day', 'data_type': 'date'}
            if target.type != 'spark' else ['date_day'],
        unique_key='issue_day_id',
        incremental_strategy = 'merge',
        file_format = 'delta'
    )
}}

-- grab column names that were pivoted out
{%- set pivot_data_columns = adapter.get_columns_in_relation(ref('int_jira__field_history_scd')) -%}

-- in intermediate/field_history/
with pivoted_daily_history as (

    select * 
    from {{ ref('int_jira__field_history_scd') }}

    {% if is_incremental() %}
    
    where valid_starting_on >= (select max(date_day) from {{ this }} )

-- If no issue fields have been updated since the last incremental run, the pivoted_daily_history CTE will return no record/rows.
-- When this is the case, we need to grab the most recent day's records from the previously built table so that we can persist 
-- those values into the future.

), most_recent_data as ( 
 
    select 
        *
    from {{ this }}
    where date_day = (select max(date_day) from {{ this }} )

{% endif %}

), field_option as (
    
    select *
    from {{ var('field_option') }}
),

-- in intermediate/field_history/
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
    
    {% if is_incremental() %}    
        {% for col in pivot_data_columns if col.name|lower not in ['issue_day_id','issue_id','valid_starting_on'] %} 
        , coalesce(pivoted_daily_history.{{ col.name }}, most_recent_data.{{ col.name }}) as {{ col.name }}
        {% endfor %}
    
    {% else %}
        {% for col in pivot_data_columns if col.name|lower not in ['issue_day_id','issue_id','valid_starting_on'] %} 
        , {{ col.name }}
        {% endfor %}
    {% endif %}
    
    from calendar
    left join pivoted_daily_history 
        on calendar.issue_id = pivoted_daily_history.issue_id
        and calendar.date_day = pivoted_daily_history.valid_starting_on
    
    {% if is_incremental() %}
    left join most_recent_data
        on calendar.issue_id = most_recent_data.issue_id
        and calendar.date_day = most_recent_data.date_day
    {% endif %}
),

set_values as (

    select
        date_day,
        issue_id

        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %}
        , coalesce(field_option_{{ col.name }}.field_option_name, {{ col.name }}) as {{ col.name }}
        -- create a batch/partition once a new value is provided
        , sum( case when {{ col.name }} is null then 0 else 1 end) over ( partition by issue_id
            order by date_day rows unbounded preceding) as {{ col.name }}_field_partition

        {% endfor %}

    from joined
    {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %}
    left join field_option as field_option_{{ col.name }}
        on cast(field_option_{{ col.name }}.field_id as {{ dbt_utils.type_string() }}) = {{ col.name }}
    {% endfor %}
),

fill_values as (

    select  
        date_day,
        issue_id

        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %}
        -- grab the value that started this batch/partition
        , first_value( {{ col.name }} ) over (
            partition by issue_id, {{ col.name }}_field_partition 
            order by date_day asc rows between unbounded preceding and current row) as {{ col.name }}
        {% endfor %}

    from set_values
),

fix_null_values as (

    select  
        date_day,
        issue_id
        {% for col in pivot_data_columns if col.name|lower not in ['issue_id','issue_day_id','valid_starting_on'] %} 

        -- we de-nulled the true null values earlier in order to differentiate them from nulls that just needed to be backfilled
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