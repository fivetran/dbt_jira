with issue as (

    select *
    from {{ ref('int_jira__issue_join' ) }}
),


final as (

    select 
        issue.*,

        {{ dbt_utils.datediff('created_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} open_duration_seconds,

        -- this will be null if no one has been assigned
        {{ dbt_utils.datediff('first_assigned_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} any_assignment_duration_seconds,

        -- if an issue is not currently assigned this will not be null
        {{ dbt_utils.datediff('last_assigned_at', "coalesce(resolved_at, " ~ dbt_utils.current_timestamp() ~ ')', 'second') }} last_assignment_duration_seconds 
    
    from issue 
        
)

select *
from final