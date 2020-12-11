with issue as (

    select *
    from {{ ref('int_jira__issue_join' ) }}
)

-- todo: add first_assigned_at, last_assigned_at, first_resolved_at from field_history
-- need to make issue metrics table
select *
from issue