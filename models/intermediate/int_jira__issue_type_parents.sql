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
        issue.issue_name,
        issue.parent_issue_id,
        issue.issue_key,
        issue_type.issue_type_name as issue_type
        
    from issue 
    
    join issue_type using (issue_type_id)
),

grab_parents as (

    select
        sub.issue_id,
        sub.issue_type,
        sub.issue_name,
        sub.issue_key,
        sub.parent_issue_id,
        parent.issue_type as parent_issue_type,
        parent.issue_name as parent_issue_name,
        parent.issue_key as parent_issue_key,
        lower(coalesce(parent.issue_type, '')) = 'epic' as is_parent_epic

    from
    grab_types as sub 

    -- do a left join so we can grab all issue types from this table in `issue_join`
    left join grab_types as parent on sub.parent_issue_id = parent.issue_id
)

select * 
from grab_parents