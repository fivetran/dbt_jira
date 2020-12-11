with issue_field_history as (

    select * from {{ var('issue_field_history') }}
),

issue_multiselect_batch_history as (

    select * from {{ ref('int_jira__agg_multiselect_history') }}
),

combine_field_history as (
-- combining all the field histories together
    select 
        field_id,
        issue_id,
        updated_at,
        field_value

    from issue_field_history

    union all

    select 
        field_id,
        issue_id,
        updated_at,
        field_values as field_value

    from issue_multiselect_batch_history
),

get_valid_dates as (


    select 
        field_id,
        issue_id,
        field_value,
        updated_at as valid_starting_at,

        -- this value is valid until the next value is updated
        lead(updated_at, 1) over(partition by issue_id, field_id order by updated_at asc) as valid_ending_at, 

        {{ dbt_utils.date_trunc('day', 'updated_at') }} as valid_starting_on

    from combine_field_history

)

select * from get_valid_dates