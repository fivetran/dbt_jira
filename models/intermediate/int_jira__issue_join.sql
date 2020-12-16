with issue as (

    select *
    from {{ var('issue') }}

),

project as (

    select * 
    from {{ var('project') }}
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

issue_epic as (

    select * 
    from {{ ref('jira__issue_epic') }}
    
),

issue_users as (

    select *
    from {{ ref('jira__issue_users') }}
),

issue_sprint as (

    select *
    from {{ ref('jira__issue_sprint') }}
),

issue_comments as (

    select * 
    from {{ ref('jira__issue_comments') }}
),

join_issue as (

    select
        issue.issue_id,
        issue.issue_name,

        issue.updated_at as last_updated_at,
        issue_type.issue_type_name as issue_type,
        issue.created_at,
        issue.issue_description,
        issue.due_date,
        issue.environment,
        issue.assignee_user_id,
        issue_users.assignee_name,
        issue.reporter_user_id,
        issue_users.reporter_name,
        issue_users.assignee_timezone,
        issue_users.assignee_email,
        
        issue.issue_key,
        issue.parent_issue_id, -- this may be the same as epic_issue_id in next-gen projects

        priority.priority_name as current_priority,

        project.project_id, 
        project.project_name,
        
        resolution.resolution_name as resolution_type,
        issue.resolved_at,

        status.status_name as current_status,
        issue.status_changed_at,

        issue_epic.epic_name,
        issue_epic.epic_issue_id,
        issue_epic.epic_key,

        issue_sprint.sprint_id,
        issue_sprint.sprint_name,
        issue_sprint.n_sprint_changes,

        issue.original_estimate_seconds,
        issue.remaining_estimate_seconds,
        issue.time_spent_seconds,
        issue.work_ratio,

        issue_comments.conversation,
        issue_comments.n_comments,

        issue._fivetran_synced
    
    from issue
    left join project on project.project_id = issue.project_id
    left join issue_type on issue_type.issue_type_id = issue.issue_type_id
    left join status on status.status_id = issue.status_id
    left join resolution on resolution.resolution_id = issue.resolution_id
    left join priority on priority.priority_id = issue.priority_id

    left join issue_users on issue_users.issue_id = issue.issue_id

    left join issue_epic on issue_epic.issue_id = issue.issue_id

    left join issue_sprint on issue_sprint.issue_id = issue.issue_id

    left join issue_comments on issue_comments.issue_id = issue.issue_id

)

select * from join_issue