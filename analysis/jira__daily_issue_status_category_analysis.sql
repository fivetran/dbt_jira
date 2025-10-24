-- get non hard-coded columns from daily_issue_field_history
{% set field_history_columns = adapter.get_columns_in_relation(ref('jira__daily_issue_field_history')) %}

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


---if you prefer to keep anayltics at the status level,skip this mapping step and join directly to statuses in the daily counts step
status_mapping as (
  select
      statuses.status_id,
      statuses.status_name,
      status_category.status_category_id,
      case
          when lower(status_category.status_category_name) = 'to do' then 'To Do'
          when lower(status_category.status_category_name) = 'in progress' then 'In Progress'
          when lower(status_category.status_category_name) = 'done' then 'Done'
          else 'Other'
      end as status_category
  from statuses
  left join status_category
      on statuses.status_category_id = status_category.status_category_id
),


daily_issue_status_category as (
  select
      field_history.date_day as report_date,
      -- add additional columns from jira__daily_issue_field_history based on the issue_field_history_columns var for your dbt project
      -- project and team have been chosen for this example
      field_history.project,
      field_history.team,
      field_history.issue_id,
      field_history.status,
      status_mapping.status_category,
  from field_history
  left join status_mapping
    on lower(field_history.status) = lower(status_mapping.status_name)
),

-- first date each issue ever appears in each status_category
first_issue_status_category_date as (
  select
    issue_id,
    status_category,
    min(report_date) as first_report_date
  from daily_issue_status_category
  group by 1,2
),


-- count of issues in each status_category on each day
daily_counts as (
  select
    report_date,
    project,
    team,
    status_category,
    count(distinct issue_id) as issues_in_status
  from daily_issue_status_category
  group by
  1,2,3,4
),

-- count of issues that are entering the status_category for the first time on that day
daily_first_counts as (
  select
    disc.report_date,
    disc.project,
    disc.team,
    disc.status_category,
    count(distinct disc.issue_id) as issues_first_in_status_category
  from daily_issue_status_category as disc
  join first_issue_status_category_date as firsts
    on disc.issue_id = firsts.issue_id
   and disc.status_category = firsts.status_category
   and disc.report_date = firsts.first_report_date
  group by
  1,2,3,4
),

-- per issue: first date seen 'in progress' and first date seen in 'done'
-- if using the status level of granularity, replace categories with desired status progression
issue_inprogress_done_dates as (
  select
    issue_id,
    any_value(project) as project,
    any_value(team) as team,
    min(case when status_category = 'In Progress' then report_date end) as first_inprogress_date,
    min(case when status_category = 'Done' then report_date end) as first_done_date
  from daily_issue_status_category
  group by 1
),

-- durations for issues that made it from 'in proegress' to 'done'
issue_days_to_done as (
  select
    issue_id,
    project,
    team,
    first_done_date,
    date_diff(first_done_date, first_inprogress_date, day) as days_to_done
  from issue_inprogress_done_dates
  where first_done_date is not null
    and first_inprogress_date is not null
    and first_done_date >= first_inprogress_date
),

-- average days-to-done by the day the issue first hits 'done'
avg_days_to_done_by_date as (
  select
    first_done_date as report_date,
    project,
    team,
    avg(days_to_done) as avg_days_to_done
  from issue_days_to_done
  group by
   1,2,3
),

-- 30-day rolling average of issues in each status
rolling as (
  select
      report_date,
      project,
      team,
      status_category,
      issues_in_status,
      --make sure to partition by all relevant dimensions brought in from daily_counts
      avg(issues_in_status) over (
          partition by project, team, status_category
          order by report_date
          rows between 29 preceding and current row
      ) as rolling_30d_avg
  from daily_counts
)

select
  daily_counts.report_date,
  daily_counts.project,
  daily_counts.team,
  daily_counts.status_category,
  daily_counts.issues_in_status,
  coalesce(daily_first_counts.issues_first_in_status_category, 0) as issues_first_in_status_category,
  rolling.rolling_30d_avg,
  avg_days_to_done_by_date.avg_days_to_done
from daily_counts
left join rolling
  on daily_counts.report_date = rolling.report_date
 and daily_counts.project = rolling.project
 and daily_counts.team = rolling.team
 and daily_counts.status_category = rolling.status_category
left join daily_first_counts
  on daily_counts.report_date = daily_first_counts.report_date
 and daily_counts.project = daily_first_counts.project
 and daily_counts.team = daily_first_counts.team
 and daily_counts.status_category = daily_first_counts.status_category
left join avg_days_to_done_by_date
  on daily_counts.report_date = avg_days_to_done_by_date.report_date
 and daily_counts.project = avg_days_to_done_by_date.project
 and daily_counts.team = avg_days_to_done_by_date.team