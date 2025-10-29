with field_history as ( 
  
  select * 
  from {{ ref('jira__daily_issue_field_history') }} 
), 

statuses as ( 

  select * 
  from {{ ref('stg_jira__status') }} 
), 

status_category as ( 

  select * 
  from {{ ref('stg_jira__status_category') }} 
), 

status_mapping as ( 

  select 
    statuses.status_id, 
    statuses.status_name, 
    status_category.status_category_id, 
    case when lower(status_category.status_category_name) = 'to do' then 'To Do' 
      when lower(status_category.status_category_name) = 'in progress' then 'In Progress' 
      when lower(status_category.status_category_name) = 'done' then 'Done' 
      else 'Other' 
    end as status_category_name 
  from statuses left join status_category 
    on statuses.status_category_id = status_category.status_category_id
), 

--if you prefer to keep analytics at the status level, substitute 'status' for 'status_category' throughout this model and skip the status_mapping step
daily_issue_status_category as ( 
  select 
    field_history.date_day as report_date, 
    -- edit field_history columns as desired based on the issue_field_history_columns var for your dbt project
    -- project and team have been chosen for this example
    field_history.project,
    field_history.team,
    field_history.issue_id, 
    field_history.status,
    status_mapping.status_category_name as status_category, 
  from field_history 
    left join status_mapping 
    on lower(field_history.status) = lower(status_mapping.status_name) 
), 

--count of issues in each status on report date 
daily_counts as ( 
  select 
    report_date, 
    project, 
    team, 
    status_category, 
    count(distinct issue_id) as issues_in_status 
  from daily_issue_status_category 
  group by 1,2,3,4 
)

select *
from daily_counts
