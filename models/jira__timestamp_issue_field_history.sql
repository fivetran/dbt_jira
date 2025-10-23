-- grab column names that were pivoted out
{% set pivot_data_columns = adapter.get_columns_in_relation(ref('int_jira__timestamp_field_history_scd')) %}

with timestamp_history_scd as (

    select *
    from {{ ref('int_jira__timestamp_field_history_scd') }}
),

statuses as (

    select *
    from {{ ref('stg_jira__status') }}
),

issue_types as (

    select *
    from {{ ref('stg_jira__issue_type') }}
),

{% if var('jira_using_components', True) %}
components as (

    select *
    from {{ ref('stg_jira__component') }}
),
{% endif %}

projects as (

    select *
    from {{ ref('stg_jira__project') }}
),

users as (

    select *
    from {{ ref('stg_jira__user') }}
),

{% if var('jira_using_teams', True) %}
teams as (

    select *
    from {{ ref('stg_jira__team') }}
),
{% endif %}

field_option as (

    select *
    from {{ ref('stg_jira__field_option') }}
),

create_validity_periods as (
    -- Create SCD Type 2 validity periods using lead() window function
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
        author_id

        -- list of exception columns
        {% set exception_cols = ['issue_id', 'issue_timestamp_id', 'updated_at', 'updated_at_week', 'status', 'author_id', 'issue_type'] %}

        {% for col in pivot_data_columns %}
            {% if col.name|lower not in exception_cols %}
            , {{ col.name }}
            {% endif %}
        {% endfor %}

    from timestamp_history_scd
),

final as (
    -- Resolve field values using lookup tables and add surrogate key
    select
        create_validity_periods.valid_from,
        coalesce(create_validity_periods.valid_until, {{ dbt.current_timestamp() }}) as valid_until,
        create_validity_periods.updated_at_week,
        create_validity_periods.issue_id,
        create_validity_periods.status_id,
        statuses.status_name as status,
        create_validity_periods.author_id

        -- list of exception columns
        {% set exception_cols = ['issue_id', 'issue_timestamp_id', 'updated_at', 'updated_at_week', 'status', 'author_id', 'components', 'issue_type', 'project', 'assignee', 'team'] %}
  
        {% for col in pivot_data_columns %}
            {% if col.name|lower == 'components' and var('jira_using_components', True) %}
            , coalesce(components.component_name, create_validity_periods.components) as components

            {% elif col.name|lower == 'issue_type' %}
            , coalesce(issue_types.issue_type_name, create_validity_periods.issue_type) as issue_type

            {% elif col.name|lower == 'project' %}
            , coalesce(projects.project_name, create_validity_periods.project) as project

            {% elif col.name|lower == 'assignee' %}
            , coalesce(users.user_display_name, create_validity_periods.assignee) as assignee

            {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
            , coalesce(teams.team_name, create_validity_periods.team) as team

            {% elif col.name|lower not in exception_cols %}
            , coalesce(field_option_{{ col.name }}.field_option_name, create_validity_periods.{{ col.name }}) as {{ col.name }}

            {% endif %}
        {% endfor %}

        , -- SCD Type 2 indicator
        case when create_validity_periods.valid_until is null then true else false end as is_current_record,
        {{ dbt_utils.generate_surrogate_key(['valid_from','issue_id']) }} as issue_timestamp_id

    from create_validity_periods

    left join statuses
        on cast(statuses.status_id as {{ dbt.type_string() }}) = create_validity_periods.status_id

    {% for col in pivot_data_columns %}
        {% if col.name|lower == 'components' and var('jira_using_components', True) %}
        left join components
            on cast(components.component_id as {{ dbt.type_string() }}) = create_validity_periods.components

        {% elif col.name|lower == 'issue_type' %}
        left join issue_types
            on cast(issue_types.issue_type_id as {{ dbt.type_string() }}) = create_validity_periods.issue_type

        {% elif col.name|lower == 'project' %}
        left join projects
            on cast(projects.project_id as {{ dbt.type_string() }}) = create_validity_periods.project

        {% elif col.name|lower == 'assignee' %}
        left join users
            on cast(users.user_id as {{ dbt.type_string() }}) = create_validity_periods.assignee
  
        {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
        left join teams
            on cast(teams.team_id as {{ dbt.type_string() }}) = create_validity_periods.team

        {% elif col.name|lower not in exception_cols %}
        left join field_option as field_option_{{ col.name }}
            on cast(field_option_{{ col.name }}.field_id as {{ dbt.type_string() }}) = create_validity_periods.{{ col.name }}

        {% endif %}
    {% endfor %}
)

select *
from final