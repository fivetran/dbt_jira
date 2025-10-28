with status_changes_only as (

  select
    issue_id,
    status,
    status_category_name,
    valid_from,
    valid_until,
    -- Track previous status to identify actual changes
    lag(status) over (partition by issue_id order by valid_from) as previous_status

  from {{ ref('jira__timestamp_issue_field_history') }}
),

issue_status_history as (

  select
    issue_id,
    status,
    status_category_name,
    valid_from,
    -- Recalculate valid_until based on next actual status change
    coalesce(
      lead(valid_from) over (partition by issue_id order by valid_from),
      {{ dbt.current_timestamp() }}
    ) as valid_until,
    previous_status,

    -- Current status indicator: if no next status change, this is current
    case when lead(valid_from) over (partition by issue_id order by valid_from) is null then true else false end as is_current_status,

    -- Calculate seconds in each status period using recalculated valid_until
    cast({{ dbt.datediff('valid_from', 'coalesce(lead(valid_from) over (partition by issue_id order by valid_from), ' ~ dbt.current_timestamp() ~ ')', 'second') }} as {{ dbt.type_int() }}) as seconds_in_status

  from status_changes_only
  -- Keep first record (no previous status) OR actual status changes
  where previous_status is null or previous_status != status
),

-- Add sequence and transition tracking
status_transitions as (

  select
    issue_id,
    status,
    status_category_name,
    valid_from as transition_at,
    valid_until as transition_until,
    is_current_status,
    seconds_in_status,

    -- Sequence tracking
    row_number() over (partition by issue_id order by valid_from) as status_sequence,

    -- Previous status tracking
    previous_status,
    lag(status_category_name) over (partition by issue_id order by valid_from) as previous_status_category_name,
    lag(valid_from) over (partition by issue_id order by valid_from) as previous_transition_at,

    -- Time in previous status
    lag(seconds_in_status) over (partition by issue_id order by valid_from) as seconds_in_previous_status

  from issue_status_history
),

-- Add transition type indicators and time calculations
final as (

  select
    issue_id,
    status,
    status_category_name,
    previous_status,
    previous_status_category_name,
    transition_at,
    transition_until,
    status_sequence,
    is_current_status, 

    -- Time spent in current status
    round(cast(seconds_in_status as {{ dbt.type_numeric() }}) / 60, 2) as minutes_in_status,

    -- Time spent in previous status (when transitioning)
    case when seconds_in_previous_status is not null
      then round(cast(seconds_in_previous_status as {{ dbt.type_numeric() }}) / 60, 2)
      else null end as minutes_in_previous_status,

    -- Workflow direction indicators
    case
      when previous_status_category_name is null then 'new'
      when previous_status_category_name = 'To Do' and status_category_name = 'In Progress' then 'forward'
      when previous_status_category_name = 'In Progress' and status_category_name = 'Done' then 'forward'
      when previous_status_category_name = 'To Do' and status_category_name = 'Done' then 'forward'
      when previous_status_category_name = 'Done' and status_category_name = 'In Progress' then 'backward'
      when previous_status_category_name = 'In Progress' and status_category_name = 'To Do' then 'backward'
      when previous_status_category_name = 'Done' and status_category_name = 'To Do' then 'backward'
      when previous_status_category_name = status_category_name then 'lateral'
      else 'other'
    end as transition_direction,

    -- Key lifecycle transitions
    case when previous_status_category_name is null and status_category_name = 'To Do' then 1 else 0 end as added_work,
    case when previous_status_category_name != 'In Progress' and status_category_name = 'In Progress' then 1 else 0 end as started_work,
    case when previous_status_category_name != 'Done' and status_category_name = 'Done' then 1 else 0 end as completed_work,
    case when previous_status_category_name = 'Done' and status_category_name != 'Done' then 1 else 0 end as reopened_work

  from status_transitions
)

select * 
from final