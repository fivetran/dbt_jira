{% macro split_sprint_ids() %}

{{ adapter.dispatch('split_sprint_ids', 'jira') () }}

{% endmacro %}

{% macro default__split_sprint_ids() %}
{# bigquery  #}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
        sprints as sprint_id

    from daily_issue_field_history
    cross join 
        unnest(cast(split(sprint, ", ") as array<string>)) as sprints

{% endmacro %}

{% macro snowflake__split_sprint_ids() %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
        sprints.value as sprint_id
    
    from daily_issue_field_history
    cross join 
        table(flatten(STRTOK_TO_ARRAY(sprint, ', '))) as sprints

{% endmacro %}

{% macro redshift__split_sprint_ids() %}
	select
        unnest_sprint_id_array.issue_id,
        unnest_sprint_id_array.source_relation,
        unnest_sprint_id_array.date_day,
        unnest_sprint_id_array.date_week,
        unnest_sprint_id_array.status,
        unnest_sprint_id_array.story_points,
        unnest_sprint_id_array.story_point_estimate,
        cast(sprint_id as {{ dbt.type_string() }}) as sprint_id
    from (
        select 
            daily_issue_field_history.issue_id,
            daily_issue_field_history.source_relation,
            daily_issue_field_history.date_day,
            daily_issue_field_history.date_week,
            daily_issue_field_history.status,
            cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
            cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
            split_to_array(sprint, ';') as super_sprint_ids

        from daily_issue_field_history
    ) as unnest_sprint_id_array, unnest_sprint_id_array.super_sprint_ids as sprint_id

{% endmacro %}

{% macro postgres__split_sprint_ids() %}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
        sprints as sprint_id

    from daily_issue_field_history
    cross join 
        unnest(string_to_array(sprint, ';')) as sprints

{% endmacro %}

{% macro spark__split_sprint_ids() %}
{# databricks and spark #}
    select
        daily_issue_field_history.issue_id,
        daily_issue_field_history.source_relation,
        daily_issue_field_history.date_day,
        daily_issue_field_history.date_week,
        daily_issue_field_history.status,
        cast(daily_issue_field_history.story_points as {{ dbt.type_float() }}) as story_points,
        cast(daily_issue_field_history.story_point_estimate as {{ dbt.type_float() }}) as story_point_estimate,
        sprints as sprint_id
    from daily_issue_field_history
    cross join (
        select 
            source_relation,
            issue_id, 
            date_day,
            explode(split(sprint, ';')) as sprints from daily_issue_field_history
    ) as sprints_subquery 
    where daily_issue_field_history.issue_id = sprints_subquery.issue_id
    and daily_issue_field_history.date_day = sprints_subquery.date_day
    and daily_issue_field_history.source_relation = sprints_subquery.source_relation

{% endmacro %}