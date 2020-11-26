with issue as (

    select *
    from {{ var('issue') }}

),

project as (

    select * 
    from {{ var('issue') }}
),

-- sprint
-- epic

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
    from {{ var('')}}
)

join_issue as (

    select
        issue.issue_id,
        issue.original_estimate_seconds,
        issue.remaining_estimate_seconds,
        issue.time_spent_seconds,
        issue.assignee_user_id,
        issue.created_at,
        issue.creator_user_id,
        issue.issue_description,
        issue.due_date,
        {# environment, #}

        issue_type as issue_type_id,
        key as issue_key,
        parent_id as parent_issue_id,
        priority as priority_id,
        project as project_id,
        reporter as reporter_user_id,
        resolution as resolution_id,
        resolved as resolved_at,
        status as status_id,
        status_category_changed as status_changed_at,
        summary as issue_name,
        updated as updated_at,
        work_ratio,
        _fivetran_synced
    
    issue
    left join project using(project_id)
    left join issue_type using(issue_type_id)
    left join status using(status_id)
    left join resolution using(resolution_id)
    left join priority using(priority_id)
)