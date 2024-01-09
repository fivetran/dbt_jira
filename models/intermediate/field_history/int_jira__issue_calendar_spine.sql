{{
    config(
        materialized='incremental',
        partition_by = {'field': 'date_day', 'data_type': 'date'}
            if target.type not in ['spark', 'databricks'] else ['date_day'],
        unique_key='issue_day_id',
        incremental_strategy = 'merge' if target.type not in ('snowflake', 'postgres', 'redshift') else 'delete+insert',
        file_format = 'delta'
    )
}}

with spine as (

    select *
    from {{ ref('int_jira__calendar_spine') }} 

    {% if is_incremental() %}
    where date_day >= (select min(earliest_open_until_date) from {{ this }})
    {% endif %}  
),

issue_dates as (
    
    select *
    from {{ ref('int_jira__field_history_scd') }}  
), 

issue_spine as (

    select 
        cast(spine.date_day as date) as date_day,
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
        earliest_open_until_date
    from issue_spine
    where date_day <= cast( {{ dbt.date_trunc('day',dbt.current_timestamp_in_utc_backcompat()) }} as date)
)

select * from surrogate_key