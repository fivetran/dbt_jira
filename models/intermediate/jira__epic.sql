-- we're creating an epic table from ISSUE instead of EPIC due to a bug
-- excluding next-gen project epics from the EPIC table. these epics are 
-- still captured in the ISSUE table, as issues with an epic `issue_type`
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