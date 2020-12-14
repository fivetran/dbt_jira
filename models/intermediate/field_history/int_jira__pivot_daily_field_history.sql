with daily_field_history as (

    select * from {{ ref('int_jira__daily_field_history') }}

),

pivot_out as (

    -- pivot out default columns (status and sprint) and others specified in the issue_field_history_columns var
    -- this will produce a bunch of 
    select 
        valid_starting_on, 
        issue_id,
        max(case when lower(field_name) = 'status' then field_value end) as status,
        max(case when lower(field_name) = 'sprint' then field_value end) as sprint,

        {% for col in var('issue_field_history_columns') -%}
            max(case when lower(field_name) = '{{ col | lower }}' then field_value end) as {{ col }}
            {% if not loop.last %},{% endif %}
        {% endfor -%}

    from daily_field_history

    group by 1,2
)

select * from pivot_out 