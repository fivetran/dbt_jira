with pivoted_daily_history as (

    select * 
    from {{ ref('int_jira__pivot_daily_field_history') }}
),

issue_field_spine as (

    select *
    from {{ ref('int_jira__issue_field_calendar_spine') }}
)

select 0

-- todo: join spine with pivoted table and backfill not-really-null values