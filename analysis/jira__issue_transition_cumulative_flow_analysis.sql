with field_history as ( 

  select * 
  from {{ ref('jira__timestamp_issue_field_history') }}

),

status_transitions as (

  select *
  from {{ ref('jira__issue_status_transitions') }}
),

---if you prefer to keep analytics at the status level, substitute 'status' for 'status_category' throughout this model
joined as (

  select 
    transitions.transition_at,
    transitions.issue_id,
    transitions.status_category_name,
    -- edit field_history columns as desired based on the issue_field_history_columns var for your dbt project
    -- project and team have been chosen for this example
    field_history.team,
    field_history.project
  from status_transitions as transitions
  join field_history 
      on transitions.issue_id = field_history.issue_id
      and transitions.transition_at = field_history.valid_from
),

---roll up to daily for reporting
daily_rollup as (
  
  select
    cast(transition_at as date) as status_category_transition_date,
    project,
    team,
    status_category_name as status_category,
    count(distinct issue_id) as issues_in_new_status_category,
  from joined
  group by 1,2,3,4
),

--add cumulative flow calculation
cumulative_flow as (
  
  select
    status_category_transition_date,
    project,
    team,
    status_category,
    issues_in_new_status_category,
    sum(issues_in_new_status_category) over (
      partition by project, team, status_category
      order by status_category_transition_date
      rows unbounded preceding
    ) as cumulative_issues_in_status_category
  from daily_rollup
)

select *
from cumulative_flow