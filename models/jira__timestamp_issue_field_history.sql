with pivoted_timestamp_history as (

    select *
    from {{ ref('int_jira__pivot_timestamp_field_history') }}
),

-- Create SCD Type 2 with validity periods using window functions
create_validity_periods as (
    select
        updated_at as valid_from,
        -- Next update becomes valid_until for this record
        lead(updated_at) over (
            partition by issue_id
            order by updated_at
        ) as valid_until,
        updated_at_week,
        issue_id,
        status,
        sprint,
        story_points,
        story_point_estimate,

        {% for col in var('issue_field_history_columns', []) -%}
        {% if col|lower not in ['story points', 'story point estimate'] %}
        {{ dbt_utils.slugify(col) | replace(' ', '_') | lower }},
        {% endif %}
        {% endfor -%}

        issue_timestamp_id

    from pivoted_timestamp_history
),

-- Handle open-ended records (current state)
final as (
    select
        valid_from,
        coalesce(valid_until, {{ dbt.current_timestamp() }}) as valid_until,
        updated_at_week,
        issue_id,
        status,
        sprint,
        story_points,
        story_point_estimate,

        {% for col in var('issue_field_history_columns', []) -%}
        {% if col|lower not in ['story points', 'story point estimate'] %}
        {{ dbt_utils.slugify(col) | replace(' ', '_') | lower }},
        {% endif %}
        {% endfor -%}

        -- SCD Type 2 indicator
        case when valid_until is null then true else false end as is_current_record,
        issue_timestamp_id

    from create_validity_periods
)

select *
from final
order by issue_id, valid_from