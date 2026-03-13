{% macro split_sprint_ids(using_teams) %}

{{ adapter.dispatch('split_sprint_ids', 'jira') (using_teams) }}

{% endmacro %}

{% macro default__split_sprint_ids(using_teams) %}
{# bigquery  #}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        cast(daily_issue_field_history.story_points as {{ dbt.type_numeric() }}) as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
        {% endif %}
        sprints as sprint_id

    from daily_issue_field_history
    cross join
        unnest(cast(split(sprint, ", ") as array<string>)) as sprints

{% endmacro %}

{% macro snowflake__split_sprint_ids(using_teams) %}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        cast(daily_issue_field_history.story_points as {{ dbt.type_numeric() }}) as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
        {% endif %}
        sprints.value as sprint_id

    from daily_issue_field_history
    cross join
        table(flatten(STRTOK_TO_ARRAY(sprint, ', '))) as sprints

{% endmacro %}

{% macro redshift__split_sprint_ids(using_teams) %}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}
	select
        unnest_sprint_id_array.issue_id,
        unnest_sprint_id_array.source_relation,
        unnest_sprint_id_array.date_day,
        unnest_sprint_id_array.date_week,
        unnest_sprint_id_array.status,
        {{ "unnest_sprint_id_array.team," if using_teams }}
        {% if include_story_points %}
        cast(unnest_sprint_id_array.story_points as {{ dbt.type_numeric() }}) as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        cast(unnest_sprint_id_array.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
        {% endif %}
        cast(sprint_id as {{ dbt.type_string() }}) as sprint_id
    from (
        select
            daily_issue_field_history.issue_id,
            daily_issue_field_history.source_relation,
            daily_issue_field_history.date_day,
            daily_issue_field_history.date_week,
            daily_issue_field_history.status,
            {{ "daily_issue_field_history.team," if using_teams }}
            {% if include_story_points %}
            cast(daily_issue_field_history.story_points as {{ dbt.type_numeric() }}) as story_points,
            {% endif %}
            {% if include_story_point_estimate %}
            cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
            {% endif %}
            split_to_array(sprint, ', ') as super_sprint_ids

        from daily_issue_field_history
    ) as unnest_sprint_id_array, unnest_sprint_id_array.super_sprint_ids as sprint_id

{% endmacro %}

{% macro postgres__split_sprint_ids(using_teams) %}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        cast(daily_issue_field_history.story_points as {{ dbt.type_numeric() }}) as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
        {% endif %}
        sprints as sprint_id

    from daily_issue_field_history
    cross join
        unnest(string_to_array(sprint, ', ')) as sprints

{% endmacro %}

{% macro spark__split_sprint_ids(using_teams) %}
{% set issue_field_history_columns = var('issue_field_history_columns', []) | map('lower') | list %}
{% set include_story_points = 'story points' in issue_field_history_columns %}
{% set include_story_point_estimate = 'story point estimate' in issue_field_history_columns %}
{# databricks and spark #}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        cast(daily_issue_field_history.story_points as {{ dbt.type_numeric() }}) as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_numeric() }}) as story_point_estimate,
        {% endif %}
        sprints as sprint_id
    from daily_issue_field_history
    lateral view explode(split(sprint, ', ')) sprints_view as sprints

{% endmacro %}
