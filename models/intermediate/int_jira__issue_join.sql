with issue as (

    select *
    from {{ ref('int_jira__issue_users') }}

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

{% if var('using_sprints', True) %}
issue_sprint as (

    select *
    from {{ ref('int_jira__issue_sprint') }}
),
{% endif %}

{% if var('include_comments', True) %}
issue_comments as (

    select * 
    from {{ ref('int_jira__issue_comments') }}
),
{% endif %}

issue_assignments_and_resolutions as (
  
  select *
  from {{ ref('int_jira__issue_assign_resolution')}}

),

join_issue as (

    select
        issue.*, 

        project.project_name as project_name,

        status.status_name as current_status,
        
        resolution.resolution_name as resolution_type,

        priority.priority_name as current_priority,

        {% if var('using_sprints', True) %}
        issue_sprint.sprint_id,
        issue_sprint.sprint_name,
        issue_sprint.count_sprint_changes,
        {% endif %}

        {% if var('include_comments', True) %}
        issue_comments.conversation,
        issue_comments.count_comments,
        {% endif %}

        issue_assignments_and_resolutions.first_assigned_at,
        issue_assignments_and_resolutions.last_assigned_at,
        issue_assignments_and_resolutions.first_resolved_at 
    
    from issue
    left join project on project.project_id = issue.project_id
    left join status on status.status_id = issue.status_id
    left join resolution on resolution.resolution_id = issue.resolution_id
    left join priority on priority.priority_id = issue.priority_id
    left join issue_assignments_and_resolutions on issue_assignments_and_resolutions.issue_id = issue.issue_id
    
    {% if var('using_sprints', True) %}
    left join issue_sprint on issue_sprint.issue_id = issue.issue_id
    {% endif %}

    {% if var('include_comments', True) %}
    left join issue_comments on issue_comments.issue_id = issue.issue_id
    {% endif %}
)

select * 
from join_issue