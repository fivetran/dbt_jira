{{ config(materialized='table') }}

{% set cycle_statuses = var('jira_cycle_time_statuses', ['In Progress', 'In Review', 'Testing']) %}
{% set lead_start_statuses = var('jira_lead_time_start_statuses', ['New', 'To Do', 'Backlog']) %}
{% set done_statuses = var('jira_done_statuses', ['Done', 'Closed', 'Resolved']) %}

with status_periods as (
  select
    issue_id,
    status,
    valid_from,
    valid_until,
    is_current_record,

    -- Calendar time calculations
    case
      when valid_until is not null
      then {{ dbt.datediff('valid_from', 'valid_until', 'second') }}
      else {{ dbt.datediff('valid_from', dbt.current_timestamp(), 'second') }}
    end as seconds_in_status,

    -- Issue lifecycle context
    min(valid_from) over (partition by issue_id) as issue_created_at,
    max(case when status in ({{ "'" + done_statuses|join("','") + "'" }})
        then valid_from end) over (partition by issue_id) as issue_completed_at,
    max(case when is_current_record then 1 else 0 end) over (partition by issue_id) as is_open_issue

  from {{ ref('jira__timestamp_issue_field_history') }}
),

-- Aggregate time by issue + status grain
status_periods_aggregated as (
  select
    issue_id,
    status,

    -- Aggregate time calculations
    sum(seconds_in_status) as total_seconds_in_status,

    -- Contextual info
    min(valid_from) as first_time_in_status,
    max(coalesce(valid_until, {{ dbt.current_timestamp() }})) as last_time_in_status,
    count(*) as times_in_this_status,

    -- Issue lifecycle context (take first non-null values)
    min(issue_created_at) as issue_created_at,
    min(issue_completed_at) as issue_completed_at,
    min(is_open_issue) as is_open_issue

  from status_periods
  group by
    issue_id, status
),

-- Convert to business-friendly time units
status_periods_with_units as (
  select *,
    round(cast(total_seconds_in_status as {{ dbt.type_numeric() }}) / 3600.0, 2) as total_hours_in_status,
    round(cast(total_seconds_in_status as {{ dbt.type_numeric() }}) / 86400.0, 2) as total_days_in_status
  from status_periods_aggregated
),

-- Issue-level cycle and lead time calculations
issue_metrics as (
  select
    issue_id,
    min(issue_created_at) as issue_created_at,
    min(issue_completed_at) as issue_completed_at,
    min(is_open_issue) as is_open_issue,

    -- Cycle time: sum of time in cycle statuses
    sum(case when status in ({{ "'" + cycle_statuses|join("','") + "'" }})
        then total_days_in_status else 0 end) as cycle_time_days,
    sum(case when status in ({{ "'" + cycle_statuses|join("','") + "'" }})
        then total_hours_in_status else 0 end) as cycle_time_hours,

    -- Lead time: total time from creation to completion
    case
      when min(issue_completed_at) is not null
      then cast({{ dbt.datediff('min(issue_created_at)', 'min(issue_completed_at)', 'day') }} as {{ dbt.type_numeric() }})
      when min(is_open_issue) = 1
      then cast({{ dbt.datediff('min(issue_created_at)', dbt.current_timestamp(), 'day') }} as {{ dbt.type_numeric() }})
      else null
    end as lead_time_days,

    case
      when min(issue_completed_at) is not null
      then cast({{ dbt.datediff('min(issue_created_at)', 'min(issue_completed_at)', 'hour') }} as {{ dbt.type_numeric() }})
      when min(is_open_issue) = 1
      then cast({{ dbt.datediff('min(issue_created_at)', dbt.current_timestamp(), 'hour') }} as {{ dbt.type_numeric() }})
      else null
    end as lead_time_hours

  from status_periods_with_units
  group by issue_id
),

final as (
  select
    status_periods_with_units.issue_id,
    status_periods_with_units.status,
    status_periods_with_units.total_seconds_in_status,
    status_periods_with_units.total_hours_in_status,
    status_periods_with_units.total_days_in_status,
    status_periods_with_units.first_time_in_status,
    status_periods_with_units.last_time_in_status,
    status_periods_with_units.times_in_this_status,
    status_periods_with_units.issue_created_at,
    status_periods_with_units.issue_completed_at,
    status_periods_with_units.is_open_issue,
    issue_metrics.cycle_time_days,
    issue_metrics.cycle_time_hours,
    issue_metrics.lead_time_days,
    issue_metrics.lead_time_hours

  from status_periods_with_units
  left join issue_metrics
    on status_periods_with_units.issue_id = issue_metrics.issue_id
)

select * from final