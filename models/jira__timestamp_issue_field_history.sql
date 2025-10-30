{%- set custom_columns = [] -%}
{%- for col in var('issue_field_history_columns', []) -%}
    {%- set clean_col = dbt_utils.slugify(col) | replace(' ', '_') | lower -%}
    {%- do custom_columns.append(clean_col) -%}
{%- endfor -%}

with timestamp_history_scd as (

    select *
    from {{ ref('int_jira__timestamp_field_history_scd') }}
),

statuses as (

    select *
    from {{ ref('stg_jira__status') }}
),

status_categories as (

    select *
    from {{ ref('stg_jira__status_category') }}
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
        {% set exception_cols = ['issue_id', 'updated_at', 'updated_at_week', 'status', 'author_id', 'issue_type'] %}
        
        {% for col in custom_columns %}
            {% if col|lower not in exception_cols %}
            , {{ col }}
            {% endif %}
        {% endfor %}

    from timestamp_history_scd
),

fix_null_values as (

    select
        create_validity_periods.valid_from,
        coalesce(create_validity_periods.valid_until, {{ dbt.current_timestamp() }}) as valid_until,
        create_validity_periods.updated_at_week,
        create_validity_periods.issue_id,
        create_validity_periods.status_id,
        statuses.status_name as status,
        status_categories.status_category_name,
        create_validity_periods.author_id

        -- list of exception columns
        {% set exception_cols = ['issue_id', 'issue_timestamp_id', 'updated_at', 'updated_at_week', 'status', 'author_id', 'components', 'issue_type', 'project', 'assignee', 'team'] %}

        {% for col in custom_columns %}
            {% if col|lower == 'components' and var('jira_using_components', True) %}
            , case when create_validity_periods.components = 'is_null' then null else create_validity_periods.components end as components

            {% elif col|lower == 'project' %}
            , case when create_validity_periods.project = 'is_null' then null else create_validity_periods.project end as project

            {% elif col|lower == 'assignee' %}
            , case when create_validity_periods.assignee = 'is_null' then null else create_validity_periods.assignee end as assignee

            {% elif col|lower == 'team' and var('jira_using_teams', True) %}
            , case when create_validity_periods.team = 'is_null' then null else create_validity_periods.team end as team

            {% elif col|lower not in exception_cols %}
            , case when create_validity_periods.{{ col }} = 'is_null' then null else create_validity_periods.{{ col }} end as {{ col }}

            {% endif %}
        {% endfor %}

        , case when create_validity_periods.valid_until is null then true else false end as is_current_record

    from create_validity_periods

    left join statuses
        on cast(statuses.status_id as {{ dbt.type_string() }}) = create_validity_periods.status_id

    left join status_categories
        on statuses.status_category_id = status_categories.status_category_id
),

final as (
    -- Resolve field values using lookup tables and add surrogate key
    select
        fix_null_values.valid_from,
        coalesce(fix_null_values.valid_until, {{ dbt.current_timestamp() }}) as valid_until,
        fix_null_values.updated_at_week,
        fix_null_values.issue_id,
        fix_null_values.status_id,
        fix_null_values.status,
        fix_null_values.status_category_name,
        fix_null_values.author_id

        {% for col in custom_columns %}
            {% if col|lower == 'components' and var('jira_using_components', True) %}
            , coalesce(components.component_name, fix_null_values.components) as components

            {% elif col|lower == 'issue_type' %}
            , coalesce(issue_types.issue_type_name, fix_null_values.issue_type) as issue_type

            {% elif col|lower == 'project' %}
            , coalesce(projects.project_name, fix_null_values.project) as project

            {% elif col|lower == 'assignee' %}
            , coalesce(users.user_display_name, fix_null_values.assignee) as assignee

            {% elif col|lower == 'team' and var('jira_using_teams', True) %}
            , coalesce(teams.team_name, fix_null_values.team) as team

            {% elif col|lower not in exception_cols %}
            , coalesce(field_option_{{ col }}.field_option_name, fix_null_values.{{ col }}) as {{ col }}

            {% endif %}
        {% endfor %}

        , fix_null_values.is_current_record
        , {{ dbt_utils.generate_surrogate_key(['fix_null_values.valid_from','fix_null_values.issue_id']) }} as issue_timestamp_id

    from fix_null_values

    {% for col in custom_columns %}
        {% if col|lower == 'components' and var('jira_using_components', True) %}
        left join components
            on cast(components.component_id as {{ dbt.type_string() }}) = fix_null_values.components

        {% elif col|lower == 'issue_type' %}
        left join issue_types
            on cast(issue_types.issue_type_id as {{ dbt.type_string() }}) = fix_null_values.issue_type

        {% elif col|lower == 'project' %}
        left join projects
            on cast(projects.project_id as {{ dbt.type_string() }}) = fix_null_values.project

        {% elif col|lower == 'assignee' %}
        left join users
            on cast(users.user_id as {{ dbt.type_string() }}) = fix_null_values.assignee

        {% elif col|lower == 'team' and var('jira_using_teams', True) %}
        left join teams
            on cast(teams.team_id as {{ dbt.type_string() }}) = fix_null_values.team

        {% elif col|lower not in exception_cols %}
        left join field_option as field_option_{{ col }}
            on cast(field_option_{{ col }}.field_id as {{ dbt.type_string() }}) = fix_null_values.{{ col }}

        {% endif %}
    {% endfor %}
)

select *
from final