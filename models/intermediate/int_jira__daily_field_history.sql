with issue_field_history as (

    select * from {{ var('issue_field_history') }}
),

issue_multiselect_batch_history as (

    select * from {{ ref('int_jira__agg_multiselect_history') }}
),

field as (

    select * from {{ var('field') }}
),

combine_field_history as (

    select 
        field_id,
        issue_id,
        updated_at,
        field_value,
        false as is_multiselect

    from issue_field_history

    union all

    select 
        field_id,
        issue_id,
        updated_at,
        field_values as field_value,
        true as is_multiselect

    from issue_multiselect_batch_history
),

limit_to_relevant_fields as (
-- and grab field names

    select combine_field_history.*, field.field_name

    from combine_field_history join field using(field_id)

    where 
    lower(field.field_name) in ('sprint', 'status' 
                                {%- for col in var('issue_field_history_columns') -%}
                                , {{ "'" ~ col ~ "'"}}
                                {%- endfor -%} )
    
),

get_last_value as (
    
    select 
        date_day,
        field_id,
        issue_id,
        field_name,
        last_value,
        max(updated_at) as last_updated_at
    from (
        select
            {{ dbt_utils.date_trunc('day', 'updated_at') }} as date_day,
            field_id,
            issue_id,
            first_value(field_value respect nulls) over(partition by issue_id, field_id order by updated_at desc) as last_value,
            updated_at,
            field_name

        from limit_to_relevant_fields
    ) 
    group by date_day, field_id, issue_id, field_name, last_value
)

select * from get_last_value