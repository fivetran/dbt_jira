{% macro split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}

{{ adapter.dispatch('split_sprint_ids', 'jira') (using_teams, include_story_points, include_story_point_estimate) }}

{% endmacro %}

{% macro default__split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}
{# bigquery  #}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_points') }} as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_point_estimate') }} as story_point_estimate,
        {% endif %}
        sprints as sprint_id

    from daily_issue_field_history
    cross join
        unnest(cast(split(sprint, ", ") as array<string>)) as sprints

{% endmacro %}

{% macro snowflake__split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_points') }} as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_point_estimate') }} as story_point_estimate,
        {% endif %}
        sprints.value as sprint_id

    from daily_issue_field_history
    cross join
        table(flatten(STRTOK_TO_ARRAY(sprint, ', '))) as sprints

{% endmacro %}

{% macro redshift__split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}
	select
        unnest_sprint_id_array.issue_id,
        unnest_sprint_id_array.source_relation,
        unnest_sprint_id_array.date_day,
        unnest_sprint_id_array.date_week,
        unnest_sprint_id_array.status,
        {{ "unnest_sprint_id_array.team," if using_teams }}
        {% if include_story_points %}
        {{ jira.convert_string_to_numeric('unnest_sprint_id_array.story_points') }} as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        {{ jira.convert_string_to_numeric('unnest_sprint_id_array.story_point_estimate') }} as story_point_estimate,
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
            daily_issue_field_history.story_points,
            {% endif %}
            {% if include_story_point_estimate %}
            daily_issue_field_history.story_point_estimate,
            {% endif %}
            split_to_array(sprint, ', ') as super_sprint_ids

        from daily_issue_field_history
    ) as unnest_sprint_id_array, unnest_sprint_id_array.super_sprint_ids as sprint_id

{% endmacro %}

{% macro postgres__split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_points') }} as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_point_estimate') }} as story_point_estimate,
        {% endif %}
        sprints as sprint_id

    from daily_issue_field_history
    cross join
        unnest(string_to_array(sprint, ', ')) as sprints

{% endmacro %}

{% macro spark__split_sprint_ids(using_teams, include_story_points=false, include_story_point_estimate=false) %}
{# databricks and spark #}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        {{ "daily_issue_field_history.team," if using_teams }}
        {% if include_story_points %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_points') }} as story_points,
        {% endif %}
        {% if include_story_point_estimate %}
        {{ jira.convert_string_to_numeric('daily_issue_field_history.story_point_estimate') }} as story_point_estimate,
        {% endif %}
        sprints as sprint_id
    from daily_issue_field_history
    lateral view explode(split(sprint, ', ')) sprints_view as sprints

{% endmacro %}
