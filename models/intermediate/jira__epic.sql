with issue as (

    select * 
    from {{ var('issue') }}
),

issue_type as (

    select *
    from {{ var('issue_type') }}
),

-- epics are stored as issues
epic_only as (

    select
        issue.*

    from issue join issue_type using(issue_type_id)

    where lower(issue_type.issue_type_name) = 'epic'
)

select * 
from epic_only