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
        field_value
        {# false as is_multiselect -- eh probably won't need this #}

    from issue_field_history

    union all

    select 
        field_id,
        issue_id,
        updated_at,
        field_values as field_value
        {# true as is_multiselect #}

    from issue_multiselect_batch_history
),

get_valid_dates as (


    select 
        field_id,
        issue_id,
        field_value,
        updated_at as valid_starting_at,
        lead(updated_at, 1) over(partition by issue_id, field_id order by updated_at asc) as valid_ending_at, -- do i need to flag if this is null....
        {{ dbt_utils.date_trunc('day', 'updated_at') }} as date_day

    from combine_field_history

)

select * from get_valid_dates