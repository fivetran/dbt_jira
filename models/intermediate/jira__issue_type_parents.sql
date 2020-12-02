with issue as (

    select * 
    from {{ var('issue') }}
    
),

issue_type as (

    select *
    from {{ var('issue_type') }}
),

grab_types as (

    select 
        issue.issue_id,
        {# issue.issue_type_id, #}
        issue_type.issue_type_name as issue_type,
        issue_type.is_subtask

    on issue join issue_type using (issue_type_id)
),

grab_parents as (

    select
        sub.issue_id,
        sub.issue_type,
        sub.parent_issue_id,
        parent.issue_type as parent_issue_type,
        parent.issue_name as parent_issue_name,
        -- lower(coalesce(sub.issue_type, '')) = 'epic' as issue_is_epic,
        lower(coalesce(parent.issue_type, '')) = 'epic' as parent_is_epic

    from
    issue sub 
    left join issue parent 
        on sub.parent_issue_id parent.issue_id
)

select * 
from grab_parents