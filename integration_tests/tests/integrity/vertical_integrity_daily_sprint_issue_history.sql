{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
    and var('jira_using_sprints', true)
) }}

with end_model as (

    select 
        sprint_id, 
        issue_id,
        min(date_day) as first_date_end
    from {{ ref('jira__daily_sprint_issue_history') }}
    group by 1,2
),


issue_multiselect_history as (

    select *
    from {{ ref('stg_jira__issue_multiselect_history') }}
),

field as (

    select *
    from {{ ref('stg_jira__field') }}
),

sprint as (

    select *
    from {{ ref('stg_jira__sprint') }}
),

all_issue_sprint_updates as (

    select
        issue_multiselect_history.issue_id,
        issue_multiselect_history.field_value as sprint_id,
        cast(issue_multiselect_history.updated_at as date) as updated_date,
        issue_multiselect_history.updated_at
    from issue_multiselect_history
    inner join field
        on field.field_id = issue_multiselect_history.field_id
    where lower(field.field_name) = 'sprint'
),

latest_timestamp_per_day as (

    select
        issue_id,
        updated_date,
        max(updated_at) as last_updated_at
    from all_issue_sprint_updates
    group by 1, 2
),

final_daily_sprint_assignment as (

    select
        all_issue_sprint_updates.issue_id,
        cast(all_issue_sprint_updates.sprint_id as int64) as sprint_id,
        all_issue_sprint_updates.updated_date
    from all_issue_sprint_updates
    inner join latest_timestamp_per_day
        on all_issue_sprint_updates.issue_id = latest_timestamp_per_day.issue_id
        and all_issue_sprint_updates.updated_date = latest_timestamp_per_day.updated_date
        and all_issue_sprint_updates.updated_at = latest_timestamp_per_day.last_updated_at
    where all_issue_sprint_updates.sprint_id is not null
),

source_model as (

    select
        final_daily_sprint_assignment.issue_id,
        final_daily_sprint_assignment.sprint_id,
        case
            -- If the issue was assigned to this sprint on or before it started, use sprint start date
            when min(case
                when final_daily_sprint_assignment.updated_date <= cast(sprint.started_at as date)
                then final_daily_sprint_assignment.updated_date
                else null
            end) is not null
            then cast(sprint.started_at as date)
            -- Otherwise use the first assignment date after sprint start within the sprint's active period
            else min(case
                when final_daily_sprint_assignment.updated_date > cast(sprint.started_at as date)
                     and (sprint.ended_at is null or final_daily_sprint_assignment.updated_date <= cast(sprint.ended_at as date))
                then final_daily_sprint_assignment.updated_date
                else null
            end)
        end as first_date_source
    from final_daily_sprint_assignment
    inner join sprint
        on final_daily_sprint_assignment.sprint_id = sprint.sprint_id
    group by 1, 2, sprint.started_at, sprint.ended_at
)

select 
    end_model.sprint_id,
    end_model.issue_id,
    first_date_source,
    first_date_end
from end_model
full outer join source_model
    on end_model.sprint_id = cast(source_model.sprint_id as string)
    and end_model.issue_id = source_model.issue_id
where first_date_source != first_date_end 