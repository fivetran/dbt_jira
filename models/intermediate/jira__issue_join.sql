with issue as (

    select *
    from {{ var('issue') }}

),

project as (

    select * 
    from {{ var('issue') }}
),

issue_type as (

    select * 
    from {{ var('issue_type') }}
),

status as (

    select * 
    from {{ var('status') }}
),

resolution as (

    select * 
    from {{ var('resolution') }}
),

priority as (

    select * 
    from {{ var('priority') }}
),

board as (

    select * 
    from {{ var('board') }}
),

{# epic as (

) #}

issue_users as (

    select *
    from {{ ref('jira__issue_users') }}
),

-- todo: agg issue comments
-- todo: get issue sprints from last sprint of field history table
-- todo: get epic from issue

join_issue as (

    select
        issue.issue_id,
        issue.original_estimate_seconds,
        issue.remaining_estimate_seconds,
        issue.time_spent_seconds,

        issue.assignee_user_id,
        issue_users.assignee_name,
        issue.reporter as reporter_user_id,
        issue_users.reporter_name,
        issue_users.assignee_timezone,

        issue.created_at,
        {# issue.creator_user_id != , #}
        issue.issue_description,
        issue.due_date,
        {# environment, #}

        issue.issue_key,
        issue.parent_issue_id, -- parent issues can be epic

        priority.priority_name as current_priority,

        project.project_id, 
        project.project_name,
        

        resolution.resolution_name as resolution_type,

        issue.resolved as resolved_at,

        status.status_name as current_status,
        issue.status_changed_at,

        issue.issue_name,

        issue.updated_at,
        issue_type.issue_type_name as issue_type,

        issue.work_ratio,
        issue._fivetran_synced
    
    from issue
    left join project using(project_id)
    left join issue_type using(issue_type_id)
    left join status using(status_id)
    left join resolution using(resolution_id)
    left join priority using(priority_id)

    left join issue_users on issue_users.issue_id = issue.issue_id
)