{{
    config(
        materialized='incremental',
        partition_by = {'field': 'valid_starting_on', 'data_type': 'date'},
        unique_key='issue_field_day_id'
    )
}}

with combined_field_histories as (

    select * 
    from {{ ref('int_jira__combine_field_histories') }}

    {% if is_incremental() %}
    where valid_starting_on >= (select max(valid_starting_on) from {{ this }} )
    {% endif %}
),

field as (

    select *
    from {{ var('field') }}
),

limit_to_relevant_fields as (
-- to remove unncessary rows moving forward and grab field names
    select 
        combined_field_histories.*, 
        field.field_name

    from combined_field_histories join field using(field_id)

    where 
    lower(field.field_name) in ('sprint', 'status' 
                                {%- for col in var('issue_field_history_columns') -%}
                                , {{ "'" ~ col ~ "'" }}
                                {%- endfor -%} )
    
),

get_latest_daily_value as (

    select * 
    from (
        select 
            *,

            -- want to grab last value for an issue's field for each day
            row_number() over (
                partition by valid_starting_on, issue_id, field_id
                order by valid_starting_at desc
                ) as row_num

        from limit_to_relevant_fields
    ) 
    where row_num = 1
), 

final as (

    select
        field_id,
        issue_id,
        field_name,

        -- doing this to figure out what values are actually null and what needs to be filled in jira__daily_issue_field_history
        case when field_value is null then 'is_null' else field_value end as field_value,
        valid_starting_at,
        valid_ending_at, 
        valid_starting_on,

        {{ dbt_utils.surrogate_key(['field_id','issue_id', 'valid_starting_at']) }} as issue_field_day_id
        
    from get_latest_daily_value
)

select * from final