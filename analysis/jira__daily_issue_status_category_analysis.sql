-- grab non hard-coded issue_field_history columns
{% set issue_field_history_columns = var('issue_field_history_columns', []) %}


with field_history as (
 select *
 from {{ ref('jira__timestamp_issue_field_history') }}
),

status_transitions as (
 select *
 from {{ ref('jira__issue_status_transitions') }}
),

---if you prefer to keep anayltics at the status level,substitute 'status' for 'status_category' throughout this model
joined as (
    select 
    transitions.transition_at,
    transitions.issue_id,
    transitions.status_category_name,
    transitions.minutes_in_status / 1440.0 as days_in_status,
    transitions.started_work,
    transitions.completed_work,
    transitions.reopened_work,
     -- edit field_history columns as desired based on the issue_field_history_columns var for your dbt project
     -- project and team have been chosen for this example
    field_history.team,
    field_history.project
  from status_transitions as transitions
    join field_history 
        on transitions.issue_id = field_history.issue_id
        and transitions.transition_at = field_history.valid_from
),

---roll up to daily for reporing
daily_rollup as (
 select
    cast(transition_at as date) as status_category_date,
    project,
    team,
    status_category_name as status_category,
    count(distinct issue_id) as issues_in_status_category,
    round(avg(days_in_status),2) as avg_days_in_status_category,
    sum(started_work) as issues_started_work,
    sum(completed_work) as issues_completed_work,
    sum(reopened_work) as issues_reopened_work   
 from joined
    group by 1,2,3,4
)
--add cumuliative flow calculation
select
  status_category_date,
  project,
  team,
  status_category,
  issues_in_status_category,
  sum(issues_in_status_category) over (
    partition by project, team, status_category
    order by status_category_date
    rows unbounded preceding
  ) as cumulative_issues_in_status_category,
  avg_days_in_status_category,
  issues_started_work,
  issues_completed_work,
  issues_reopened_work
from daily_rollup