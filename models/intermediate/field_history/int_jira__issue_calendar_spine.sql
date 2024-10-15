with spine as (

    {% if execute and flags.WHICH in ('run', 'build') %}
    {% set first_date_query %}
    -- start at the first created issue
        select  
            coalesce(
                min(cast(created as date)),
                cast({{ dbt.dateadd("month", -1, "current_date") }} as date)
            ) as min_date
        from {{ source('jira','issue') }}
    {% endset %}

    {%- set first_date = dbt_utils.get_single_value(first_date_query) %}
    
    {% else %} {% set first_date = "2016-01-01" %}
    {% endif %}

    select
        cast(date_day as date) as date_day
    from (
        {{
            dbt_utils.date_spine(
                datepart = "day", 
                start_date = "cast('" ~ first_date ~ "' as date)",
                end_date = dbt.dateadd("week", 1, dbt.current_timestamp())
            )   
        }}
    ) as date_spine
),

issue_history_scd as (
    
    select *
    from {{ ref('int_jira__field_history_scd') }}
),

issue_dates as (

    select
        issue_history_scd.issue_id,
        cast( {{ dbt.date_trunc('day', 'issue.created_at') }} as date) as created_on,
        -- resolved_at will become null if an issue is marked as un-resolved. if this sorta thing happens often, you may want to run full-refreshes of the field_history models often
        -- if it's not resolved include everything up to today. if it is, look at the last time it was updated 
        cast({{ dbt.date_trunc('day',
            'case when issue.resolved_at is null then ' ~ dbt.current_timestamp() ~ ' else cast(issue_history_scd.valid_starting_on as ' ~ dbt.type_timestamp() ~ ') end') }}
            as date) as open_until
    from issue_history_scd
    left join {{ var('issue') }} as issue
        on issue_history_scd.issue_id = issue.issue_id
),

issue_spine as (

    select 
        spine.date_day,
        issue_dates.issue_id,
        -- will take the table-wide min of this in the incremental block at the top of this model
        min(issue_dates.open_until) as earliest_open_until_date

    from spine 
    join issue_dates on
        issue_dates.created_on <= spine.date_day
        and {{ dbt.dateadd('month', var('jira_issue_history_buffer', 1), 'issue_dates.open_until') }} >= spine.date_day
        -- if we cut off issues, we're going to have to do a full refresh to catch issues that have been un-resolved
    group by 1,2
),

surrogate_key as (

    select 
        date_day,
        issue_id,
        {{ dbt_utils.generate_surrogate_key(['date_day','issue_id']) }} as issue_day_id,
        earliest_open_until_date,
        cast({{ dbt.date_trunc('week', 'earliest_open_until_date') }} as date) as earliest_open_until_week

    from issue_spine

    where date_day <= cast( {{ dbt.current_timestamp() }} as date)
)

select *
from surrogate_key 