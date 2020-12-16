with project as (

    select *
    from {{ var('project') }}
),

issue as (

    select * 
    from {{ ref('jira__issue_enhanced') }}
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

    from issue
    where lower(issue_type) = 'epic'

    group by 1

),

agg_components as (
    -- i'm just aggregating the components here, but perhaps pivoting out components (and epics) 
    -- into columns where the values are the number of issues completed and/or open would be more valuable...
    select 
        project_id,
        {{ fivetran_utils.string_agg( "component_name", "', '" ) }} as components

    from {{ var('component') }}

    group by 1
),

project_issues as (
    select
        project_id,
        sum(case when resolved_at is not null then 1 else 0 end) as n_closed_issues,
        sum(case when resolved at is null then 1 else 0 end) as n_open_issues,
        sum(case when resolved at is null and and assignee_user_id is not null then 1 else 0 end) as n_open_assigned_issues,

        sum(unassigned_duration_seconds) as sum_unassigned_duration_seconds, -- to divide by # of unassigned issues
        sum(open_duration_seconds) as sum_open_duration_seconds, -- to divide by # open issues
        sum(case when last_assignment_duration_seconds is not null then last_assignment_duration_seconds else 0 end) as sum_last_assignment_duration_seconds

    from issue
)