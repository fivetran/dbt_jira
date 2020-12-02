with issue as (

    select * 
    from {{ var('issue') }}
),

issue_type as (

    select *
    from {{ var('issue_type') }}
),

epic_only as (

    select
        issue.*,
        issue_type.issue_type_name as issue_type,


    from issue join issue_type using(issue_type_id)

    where lower(issue_type.name) = 'epic'
)

select * 
from epic_only