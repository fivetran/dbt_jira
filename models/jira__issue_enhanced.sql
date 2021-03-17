with issue as (

    select *
    from {{ ref('int_jira__issue_join' ) }}
),

{%- set pivot_data_columns = adapter.get_columns_in_relation(ref('jira__daily_issue_field_history')) -%}

daily_issue_field_history as (
    
    select
        *,
        row_number() over (partition by issue_id order by date_day desc) = 1 as latest_record
    from {{ ref('jira__daily_issue_field_history')}}

),

latest_issue_field_history as (
    
    select
        *
    from daily_issue_field_history
    where latest_record
),

final as (

    select 
        issue.*,

        {{ dbt_utils.datediff('created_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} open_duration_seconds,

        -- this will be null if no one has been assigned
        {{ dbt_utils.datediff('first_assigned_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} any_assignment_duration_seconds,

        -- if an issue is not currently assigned this will not be null
        {{ dbt_utils.datediff('last_assigned_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} last_assignment_duration_seconds 
    
        {% for col in pivot_data_columns if col.name|lower not in ['issue_day_id','issue_id','latest_record', 'date_day'] %} 
        , {{ col.name }}
        {% endfor %}

    from issue
    left join latest_issue_field_history using (issue_id)
        
)

select *
from final