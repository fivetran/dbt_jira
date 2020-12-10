with daily_field_history as (

    select * from {{ ref('int_jira__daily_field_history') }}

),

pivot_out as (
    select 
        valid_starting_on, 
        issue_id,

        {% for col in var('issue_field_history_columns') -%}
            max(case when lower(field_name) = '{{ col | lower }}' then field_value end) as {{ col }}
            {% if not loop.last %},{% endif %}
        {% endfor -%}

    from daily_field_history -- do i need valid_ending_at??

)

select * from pivot_out -- todo: backfill stuff for valid_until