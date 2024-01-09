with spine as (

    {% if execute %}
    {% set first_date_query %}
    -- start at the first created issue
        select  min( created ) as min_date from {{ source('jira','issue') }}
    {% endset %}
    {% set first_date = run_query(first_date_query).columns[0][0]|string %}
    
    {% else %} {% set first_date = "2016-01-01" %}
    {% endif %}


    select * 
    from (
        {{
            dbt_utils.date_spine(
                datepart = "day", 
                start_date =  "cast('" ~ first_date[0:10] ~ "' as date)", 
                end_date = dbt.dateadd("week", 1, dbt.current_timestamp_in_utc_backcompat())
            )   
        }} 
    ) as date_spine

),

recast as (

    select cast(date_day as date) as date_day
    from spine
)

select *
from recast