with spine as (

    {% if execute %}
    {% set first_date_query %}
    -- start at the first created issue
        select  min( created_at ) as min_date from {{ var('issue') }}
    {% endset %}
    {% set first_date = run_query(first_date_query).columns[0][0]|string %}
    
    {% else %} {% set first_date = "'2016-01-01'" %}
    {% endif %}

    {{
        dbt_utils.date_spine(
            datepart = "day", 
            start_date =  "'" ~ first_date[0:10] ~ "'", 
            end_date = dbt_utils.dateadd("week", 1, "current_date")
        )   
    }}
),

issue_dates as (

    select
        issue_id,
        cast({{ dbt_utils.date_trunc('day', 'created_at') }} as date) as created_on,

        -- note: resolved_at will become null if an issue is marked as un-resolved. if this sorta thing happens often, you may want to run full-refreshes of the field_history models often
        cast({{ dbt_utils.date_trunc('day', 'coalesce(resolved_at, ' ~ dbt_utils.current_timestamp() ~ ')') }} as date) as open_until 

    from {{ var('issue') }}

),

issue_spine as (

    select 
        cast(spine.date_day as date) as date_day,
        issue_dates.issue_id

    from spine 
    join issue_dates on
        issue_dates.created_on <= spine.date_day
        and issue_dates.open_until >= spine.date_day 
        -- if we cut off issues, we're going to have to do a full refresh (assuming this is incremental) to catch issues that have been un-resolved

    group by 1,2
)

select * from issue_spine 