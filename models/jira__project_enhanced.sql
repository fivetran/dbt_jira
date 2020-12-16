with project as (

    select *
    from {{ var('project') }}
),

project_metrics as (

    select * 
    from {{ ref('int_jira__project_metrics') }}
),

user as (
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

    group by 1

),

agg_components as (
    -- i'm just aggregating the components here, but perhaps pivoting out components (and epics) 
    -- into columns where the values are the number of issues completed and/or open would be more valuable
    select 
        project_id,
        {{ fivetran_utils.string_agg( "component_name", "', '" ) }} as components

    from {{ var('component') }}

    group by 1
),

project_join as (

    select
        project.*,
        user.user_display_name as project_lead_user_name,
        user.email as project_lead_email,
        agg_epics.epics,
        agg_components.components,
        project_metrics.n_closed_issues,
        project_metrics.n_open_issues,
        project_metrics.n_open_assigned_issues,

        project_metrics.avg_close_time_seconds,
        project_metrics.avg_assigned_close_time_seconds,

        project_metrics.avg_age_currently_open_seconds,
        project_metrics.avg_age_currently_open_assigned_seconds

    from project
    left join project_metrics on project.project_id = project_metrics.project_id
    left join user on project.project_lead_user_id = user.user_id
    left join agg_epics on project.project_id = agg_epics.project_id 
    left join agg_components on project.project_id = agg_components.project_id 
)

select * from project_join