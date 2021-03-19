with project as (

    select *
    from {{ var('project') }}
),

project_metrics as (

    select * 
    from {{ ref('int_jira__project_metrics') }}
),

-- user is reserved in AWS
jira_user as (
-- to grab the project lead
    select *
    from {{ var('user') }}
),

agg_epics as (

    select 
        project_id,
        {{ fivetran_utils.string_agg( "issue_name", "', '" ) }} as epics

    from {{ ref('jira__issue_enhanced') }}
    where lower(issue_type) = 'epic'
    -- should we limit to active epics?
    group by 1

),

{% if var('jira_using_components', True) %}

agg_components as (
    -- i'm just aggregating the components here, but perhaps pivoting out components (and epics) 
    -- into columns where the values are the number of issues completed and/or open would be more valuable
    select 
        project_id,
        {{ fivetran_utils.string_agg( "component_name", "', '" ) }} as components

    from {{ var('component') }}

    group by 1
),

{% endif %}

project_join as (

    select
        project.*,
        jira_user.user_display_name as project_lead_user_name,
        jira_user.email as project_lead_email,
        agg_epics.epics,
        
        {% if var('jira_using_components', True) %}
        agg_components.components,
        {% endif %}

        coalesce(project_metrics.count_closed_issues, 0) as count_closed_issues,
        coalesce(project_metrics.count_open_issues, 0) as count_open_issues,
        coalesce(project_metrics.count_open_assigned_issues, 0) as count_open_assigned_issues,

        -- days
        project_metrics.avg_close_time_days,
        project_metrics.avg_assigned_close_time_days,

        project_metrics.avg_age_currently_open_days,
        project_metrics.avg_age_currently_open_assigned_days,

        project_metrics.median_close_time_days, 
        project_metrics.median_age_currently_open_days,
        project_metrics.median_assigned_close_time_days,
        project_metrics.median_age_currently_open_assigned_days,

        -- seconds
        project_metrics.avg_close_time_seconds,
        project_metrics.avg_assigned_close_time_seconds,

        project_metrics.avg_age_currently_open_seconds,
        project_metrics.avg_age_currently_open_assigned_seconds,

        project_metrics.median_close_time_seconds, 
        project_metrics.median_age_currently_open_seconds,
        project_metrics.median_assigned_close_time_seconds,
        project_metrics.median_age_currently_open_assigned_seconds

    from project
    left join project_metrics on project.project_id = project_metrics.project_id
    left join jira_user on project.project_lead_user_id = jira_user.user_id
    left join agg_epics on project.project_id = agg_epics.project_id 
    
    {% if var('jira_using_components', True) %}
    left join agg_components on project.project_id = agg_components.project_id 
    {% endif %}

)

select * from project_join