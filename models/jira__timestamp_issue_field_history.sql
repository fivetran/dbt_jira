with timestamp_history_scd as (

    select *
    from {{ ref('int_jira__timestamp_field_history_scd') }}
),

statuses as (

    select *
    from {{ ref('stg_jira__status') }}
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
        status as status_id,
        author_id,
        sprint,
        story_points,
        story_point_estimate,

        {% for col in var('issue_field_history_columns', []) -%}
        {% if col|lower not in ['story points', 'story point estimate'] %}
        {{ dbt_utils.slugify(col) | replace(' ', '_') | lower }},
        {% endif %}
        {% endfor -%}

        issue_timestamp_id

    from timestamp_history_scd
),

-- Handle open-ended records (current state) and resolve status
final as (
    select
        create_validity_periods.valid_from,
        coalesce(create_validity_periods.valid_until, {{ dbt.current_timestamp() }}) as valid_until,
        create_validity_periods.updated_at_week,
        create_validity_periods.issue_id,
        create_validity_periods.status_id,
        statuses.status_name as status,
        create_validity_periods.author_id,
        create_validity_periods.sprint,
        create_validity_periods.story_points,
        create_validity_periods.story_point_estimate,

        {% for col in var('issue_field_history_columns', []) -%}
        {% if col|lower not in ['story points', 'story point estimate'] %}
        create_validity_periods.{{ dbt_utils.slugify(col) | replace(' ', '_') | lower }},
        {% endif %}
        {% endfor -%}

        -- SCD Type 2 indicator
        case when create_validity_periods.valid_until is null then true else false end as is_current_record,
        create_validity_periods.issue_timestamp_id

    from create_validity_periods

    left join statuses
        on cast(statuses.status_id as {{ dbt.type_string() }}) = create_validity_periods.status_id
)

select *
from final
order by issue_id, valid_from