with issue as (

    select *
    from {{ ref('int_jira__issue_join' ) }}
),

issue_field_history as (
    -- we're only looking at assignments and resolutions
    select *
    from {{ var('issue_field_history') }}

    where (lower(field_id) = 'assignee'
    or lower(field_id) = 'resolutiondate')

    and field_value is not null -- remove initial null rows
),

issue_dates as (
    select
        issue_id,
        min(case when field_id = 'assignee' then updated_at end) as first_assigned_at,
        max(case when field_id = 'assignee' then updated_at end) as last_assigned_at,
        min(case when field_id = 'resolutiondate' then updated_at end) as first_resolved_at

    from issue_field_history
    group by 1
),

final as (

    select 
        issue.*,
        issue_dates.first_assigned_at,
        issue_dates.last_assigned_at,
        issue_dates.first_resolved_at
    
    from issue left join issue_dates using(issue_id)
        
)

select *
from final