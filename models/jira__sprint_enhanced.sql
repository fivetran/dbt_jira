{{ config(enabled=var('jira_using_sprints', True)) }}

with sprint as (

    select *
    from {{ var('sprint') }}
),

issue_enhanced as (

    select *
    from {{ ref('jira__issue_enhanced') }}
)

final as (

    select 
        sprint.sprint_id
        ,sprint.sprint_name 
        ,sprint.board_id
        ,sprint.started_at as sprint_started_at
        ,sprint.ended_at as sprint_ended_at
        ,sprint.completed_at as sprint_completed_at
        ,coalesce(sprint.started_at <= {{ dbt.current_timestamp() }}
          and coalesce(sprint.completed_at, {{ dbt.current_timestamp() }}) >= {{ dbt.current_timestamp() }}  
          , false) as is_active_sprint -- If sprint doesn't have a start date, default to false. If it does have a start date, but no completed date, this means that the sprint is active. The ended_at timestamp is irrelevant here. 
        ,sum(case when issue_enhanced.current_story_points is null then 0 else issue_enhanced.current_story_points end) as current_story_points
        ,sum(case when issue_enhanced.current_story_points_estimate is null then 0 else issue_enhanced.current_estimated_story_points end) as current_estimated_story_points
        ,sum(issue_enhanced.original_estimate_seconds)
        ,sum(issue_enhanced.remaining_estimate_seconds)
        ,sum(issue_enhanced.time_spent_seconds)
        ,count(distinct issue_enhanced.issue_id) as issues_per_sprint
        ,sum(issue_enhanced.count_sp_changes) as count_sp_changes
        ,sum(issue_enhanced.count_estimated_sp_changes) as count_estimated_sp_changes
        {% if var('jira_using_sprints', True) %} 
        ,sum(issue_enhanced.count_sprint_changes) as count_sprint_issue_changes
        {% endif %}
    from sprint
    left join issue_enhanced 
        on cast(sprint.sprint_id as {{ dbt.type_string() }}) = issue_enhanced.current_sprint_id
    {{ dbt_utils.group_by(6) }}
)

select *
from final