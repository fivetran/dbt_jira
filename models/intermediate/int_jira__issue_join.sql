with issue as (

    select *
    from {{ var('issue') }}

),

project as (

    select * 
    from {{ var('project') }}
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
    from {{ ref('int_jira__issue_epic') }}
    
),

issue_users as (

    select *
    from {{ ref('int_jira__issue_users') }}
),

issue_sprint as (

    select *
    from {{ ref('int_jira__issue_sprint') }}
),

issue_comments as (

    select * 
    from {{ ref('int_jira__issue_comments') }}
),

-- this has issues without parents as well
issue_type_parent as (
    
    select *
    from {{ ref('int_jira__issue_type_parents') }}
),

join_issue as (

    select
        issue.issue_id,
        issue.issue_name,

        issue.updated_at as last_updated_at,
        issue_type_parent.issue_type,
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
        issue_type_parent.parent_issue_name,
        issue_type_parent.parent_issue_key,
        issue_type_parent.parent_issue_type,
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
    left join status on status.status_id = issue.status_id
    left join resolution on resolution.resolution_id = issue.resolution_id
    left join priority on priority.priority_id = issue.priority_id

    left join issue_users on issue_users.issue_id = issue.issue_id
    left join issue_epic on issue_epic.issue_id = issue.issue_id
    left join issue_sprint on issue_sprint.issue_id = issue.issue_id
    left join issue_comments on issue_comments.issue_id = issue.issue_id
    left join issue_type_parent on issue_type_parent.issue_id = issue.issue_id

)

select * from join_issue