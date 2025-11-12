{{
    config(
        materialized='incremental' if jira_is_incremental_compatible() else 'table',
        partition_by = {'field': 'date_week', 'data_type': 'date'}
            if target.type not in ['spark', 'databricks'] else ['date_week'],
        cluster_by = ['date_week'],
        unique_key='issue_day_id',
        incremental_strategy = 'insert_overwrite' if target.type in ('bigquery', 'databricks', 'spark') else 'delete+insert',
        file_format='delta'
    )
}}

-- grab column names that were pivoted out
{%- set pivot_data_columns = adapter.get_columns_in_relation(ref('int_jira__field_history_scd')) -%}

{% if is_incremental() %}
-- set max date_day with lookback as a variable for multiple uses
{% set max_date_week = jira.jira_lookback(from_date='max(date_week)', datepart='week', interval=var('lookback_window', 1)) %}
{% endif %}

-- in intermediate/field_history/
with pivoted_daily_history as (

    select * 
    from {{ ref('int_jira__field_history_scd') }}

    {% if is_incremental() %}
    where valid_starting_on >= {{ max_date_week }}
), 

-- If no issue fields have been updated since the last incremental run, the pivoted_daily_history CTE will return no record/rows.
-- When this is the case, we need to grab the most recent week's records from the previously built table so that we can persist 
-- those values into the future.

most_recent_data as ( 
    select 
        *
    from {{ this }}
    where date_day >= {{ max_date_week }}
{% endif %}
), 

-- in intermediate/field_history/
calendar as (

    select *
    from {{ ref('int_jira__issue_calendar_spine') }}

    {% if is_incremental() %}
    where date_day >= {{ max_date_week }}
    {% endif %}
), 

field_option as (
    
    select *
    from {{ ref('stg_jira__field_option') }}
),

statuses as (
    
    select *
    from {{ ref('stg_jira__status') }}
),

issue_types as (
    
    select *
    from {{ ref('stg_jira__issue_type') }}
),

{% if var('jira_using_teams', True) %}
teams as ( 

    select * 
    from {{ ref('stg_jira__team') }} 
),
{% endif %}

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

joined as (

    select
        calendar.date_day,
        calendar.issue_id,
        calendar.source_relation

        {% if is_incremental() %}    
            {% for col in pivot_data_columns %}
                {% if col.name|lower == 'components' and var('jira_using_components', True) %}
                , coalesce(pivoted_daily_history.components, most_recent_data.components) as components

                {% elif col.name|lower == 'team' and var('jira_using_teams', True) %} 
                , coalesce(pivoted_daily_history.team, most_recent_data.team) as team 

                {% elif col.name|lower not in ['issue_day_id', 'issue_id', 'valid_starting_on', 'valid_starting_at_week', 'components', 'team', 'source_relation'] %}
                , coalesce(pivoted_daily_history.{{ col.name }}, most_recent_data.{{ col.name }}) as {{ col.name }}

                {% endif %}
            {% endfor %} 

        {% else %}
            {% for col in pivot_data_columns %}
                {% if col.name|lower == 'components' and var('jira_using_components', True) %}
                , pivoted_daily_history.components

                {% elif col.name|lower == 'team' and var('jira_using_teams', True) %} 
                , pivoted_daily_history.team

                {% elif col.name|lower not in ['issue_day_id', 'issue_id', 'valid_starting_on', 'valid_starting_at_week', 'components','team', 'source_relation'] %}
                , pivoted_daily_history.{{ col.name }}

                {% endif %}
            {% endfor %} 
        {% endif %} 
    
    from calendar
    left join pivoted_daily_history
        on calendar.issue_id = pivoted_daily_history.issue_id
        and calendar.source_relation = pivoted_daily_history.source_relation
        and calendar.date_day = pivoted_daily_history.valid_starting_on

    {% if is_incremental() %}
    left join most_recent_data
        on calendar.issue_id = most_recent_data.issue_id
        and calendar.source_relation = most_recent_data.source_relation
        and calendar.date_day = most_recent_data.date_day
    {% endif %}
),

set_values as (
    select
        joined.date_day,
        joined.issue_id,
        joined.source_relation,
        joined.status_id,
        sum( case when joined.status_id is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }}
            order by date_day rows unbounded preceding) as status_id_field_partition

        -- list of exception columns
        {% set exception_cols = ['issue_id', 'issue_day_id', 'valid_starting_on', 'valid_starting_at_week', 'status', 'status_id', 'components', 'issue_type', 'project', 'assignee', 'team', 'source_relation'] %}

        {% for col in pivot_data_columns %}
            {% if col.name|lower == 'components' and var('jira_using_components', True) %}
            , coalesce(components.component_name, joined.components) as components
            , sum(case when joined.components is null then 0 else 1 end) over (partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }} order by date_day rows unbounded preceding) as component_field_partition

            {% elif col.name|lower == 'issue_type' %}
            , coalesce(issue_types.issue_type_name, joined.issue_type) as issue_type
            , sum(case when joined.issue_type is null then 0 else 1 end) over (partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }} order by date_day rows unbounded preceding) as issue_type_field_partition

            {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
            , coalesce(teams.team_name, joined.team) as team
            , sum(case when joined.team is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }}
                order by date_day rows unbounded preceding) as team_field_partition

            {% elif col.name|lower == 'project' %}
            , coalesce(projects.project_name, joined.project) as project
            , sum(case when joined.project is null then 0 else 1 end) over (partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }} order by date_day rows unbounded preceding) as project_field_partition

            {% elif col.name|lower == 'assignee' %}
            , coalesce(users.user_display_name, joined.assignee) as assignee
            , sum(case when joined.assignee is null then 0 else 1 end) over (partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }} order by date_day rows unbounded preceding) as assignee_field_partition

            {% elif col.name|lower not in exception_cols %}
            , coalesce(field_option_{{ col.name }}.field_option_name, joined.{{ col.name }}) as {{ col.name }}
            -- create a batch/partition once a new value is provided
            , sum( case when joined.{{ col.name }} is null then 0 else 1 end) over ( partition by issue_id {{ jira.partition_by_source_relation(alias='joined') }}
                order by date_day rows unbounded preceding) as {{ col.name }}_field_partition

            {% endif %}
        {% endfor %}

    from joined

    {% for col in pivot_data_columns %}
        {% if col.name|lower == 'components' and var('jira_using_components', True) %}
        left join components
            on cast(components.component_id as {{ dbt.type_string() }}) = joined.components
            and components.source_relation = joined.source_relation

        {% elif col.name|lower == 'issue_type' %}
        left join issue_types
            on cast(issue_types.issue_type_id as {{ dbt.type_string() }}) = joined.issue_type
            and issue_types.source_relation = joined.source_relation

        {% elif col.name|lower == 'project' %}
        left join projects
            on cast(projects.project_id as {{ dbt.type_string() }}) = joined.project
            and projects.source_relation = joined.source_relation

        {% elif col.name|lower == 'assignee' %}
        left join users
            on cast(users.user_id as {{ dbt.type_string() }}) = joined.assignee
            and users.source_relation = joined.source_relation

        {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
        left join teams
            on cast(teams.team_id as {{ dbt.type_string() }}) = joined.team
            and teams.source_relation = joined.source_relation

        {% elif col.name|lower not in exception_cols %}
        left join field_option as field_option_{{ col.name }}
            on cast(field_option_{{ col.name }}.field_id as {{ dbt.type_string() }}) = joined.{{ col.name }}
            and field_option_{{ col.name }}.source_relation = joined.source_relation

        {% endif %}
    {% endfor %}
),

fill_values as (

    select
        date_day,
        issue_id,
        source_relation,
        first_value( status_id ) over (
            partition by issue_id, status_id_field_partition {{ jira.partition_by_source_relation() }}
            order by date_day asc rows between unbounded preceding and current row) as status_id

        {% for col in pivot_data_columns %}
            {% if col.name|lower == 'components' and var('jira_using_components', True) %}
            , first_value(components) over (
                partition by issue_id, component_field_partition {{ jira.partition_by_source_relation() }}
                order by date_day asc rows between unbounded preceding and current row) as components

            {% elif col.name|lower == 'project' %}
            , first_value(project) over (
                partition by issue_id, project_field_partition {{ jira.partition_by_source_relation() }}
                order by date_day asc rows between unbounded preceding and current row) as project

            {% elif col.name|lower == 'assignee' %}
            , first_value(assignee) over (
                partition by issue_id, assignee_field_partition {{ jira.partition_by_source_relation() }}
                order by date_day asc rows between unbounded preceding and current row) as assignee

            {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
            , first_value(team) over (
                partition by issue_id, team_field_partition {{ jira.partition_by_source_relation() }}
                order by date_day asc rows between unbounded preceding and current row) as team

            {% elif col.name|lower not in ['issue_id', 'issue_day_id', 'valid_starting_on', 'valid_starting_at_week', 'status', 'status_id', 'components', 'project', 'assignee', 'team', 'source_relation'] %}

            -- grab the value that started this batch/partition
            , first_value( {{ col.name }} ) over (
                partition by issue_id, {{ col.name }}_field_partition {{ jira.partition_by_source_relation() }}
                order by date_day asc rows between unbounded preceding and current row) as {{ col.name }}

            {% endif %}
        {% endfor %}

    from set_values
),

fix_null_values as (

    select
        date_day,
        issue_id,
        source_relation

        {% for col in pivot_data_columns %}
            {% if col.name|lower == 'components' and var('jira_using_components', True) %}
            , case when components = 'is_null' then null else components end as components

            {% elif col.name|lower == 'project' %}
            , case when project = 'is_null' then null else project end as project

            {% elif col.name|lower == 'assignee' %}
            , case when assignee = 'is_null' then null else assignee end as assignee

            {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
            , case when team = 'is_null' then null else team end as team

            {% elif col.name|lower not in ['issue_id','issue_day_id','valid_starting_on', 'valid_starting_at_week', 'status', 'components', 'project', 'assignee', 'team', 'source_relation'] %}
            -- we de-nulled the true null values earlier in order to differentiate them from nulls that just needed to be backfilled
            , case when {{ col.name }} = 'is_null' then null else {{ col.name }} end as {{ col.name }}

            {% endif %}
        {% endfor %}

    from fill_values

),

surrogate_key as (

    select
        fix_null_values.date_day,
        cast({{ dbt.date_trunc('week', 'fix_null_values.date_day') }} as date) as date_week,
        fix_null_values.issue_id,
        fix_null_values.source_relation,
        statuses.status_name as status

        {% for col in pivot_data_columns %}
            {% if col.name|lower == 'components' and var('jira_using_components', True) %}
            , fix_null_values.components as components

            {% elif col.name|lower == 'project' %}
            , fix_null_values.project as project

            {% elif col.name|lower == 'assignee' %}
            , fix_null_values.assignee as assignee

            {% elif col.name|lower == 'team' and var('jira_using_teams', True) %}
            , fix_null_values.team as team

            {% elif col.name|lower not in ['issue_id','issue_day_id','valid_starting_on', 'valid_starting_at_week', 'status', 'components', 'project', 'assignee', 'team', 'source_relation'] %}
            , fix_null_values.{{ col.name }} as {{ col.name }}

            {% endif %}
        {% endfor %}

        , {{ dbt_utils.generate_surrogate_key(['fix_null_values.date_day','fix_null_values.issue_id','fix_null_values.source_relation']) }} as issue_day_id

    from fix_null_values

    left join statuses
        on cast(statuses.status_id as {{ dbt.type_string() }}) = fix_null_values.status_id
        and statuses.source_relation = fix_null_values.source_relation
)

select *
from surrogate_key