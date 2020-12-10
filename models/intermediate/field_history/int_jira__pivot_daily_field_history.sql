with daily_field_history as (

    select * from {{ ref('int_jira__daily_field_history') }}

),

pivot_out as (
    select 
        date_day, -- this is the first day it is valid
        issue_id,

        {% for col in var('issue_field_history_columns') -%}
            max(case when lower(field_name) = '{{ col | lower }}' then last_value end) as {{ col }}
            {% if not loop.last %},{% endif %}
        {% endfor -%}
        {# field_name,
        last_value,
        last_updated_at #}

    from daily_field_history

    group by 1,2
)

select * from pivot_out -- todo: backfill stuff for valid_until