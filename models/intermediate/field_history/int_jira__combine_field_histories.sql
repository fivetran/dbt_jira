{{
    config(
        materialized='incremental',
        partition_by = {'field': 'valid_starting_on', 'data_type': 'date'}
            if target.type != 'spark' else ['valid_starting_on'],
        unique_key='combined_history_id',
        incremental_strategy = 'merge',
        file_format = 'delta'
    )
}}

with issue_field_history as (

    select * from {{ ref('int_jira__issue_field_history') }}

    {% if is_incremental() %}
    where cast( updated_at as date) >= (select max(valid_starting_on) from {{ this }} )
    {% endif %}
),

issue_multiselect_batch_history as (

    select * from {{ ref('int_jira__agg_multiselect_history') }}

    {% if is_incremental() %}
    where cast( updated_at as date) >= (select max(valid_starting_on) from {{ this }} )
    {% endif %}
),

combine_field_history as (
-- combining all the field histories together
    select 
        field_id,
        issue_id,
        updated_at,
        field_value,
        field_name

    from issue_field_history

    union all

    select 
        field_id,
        issue_id,
        updated_at,
        field_values as field_value, -- this is an aggregated list but we'll just call it field_value
        field_name

    from issue_multiselect_batch_history
),

get_valid_dates as (


    select 
        field_id,
        issue_id,
        field_value,
        field_name,
        updated_at as valid_starting_at,

        -- this value is valid until the next value is updated
        lead(updated_at, 1) over(partition by issue_id, field_id order by updated_at asc) as valid_ending_at, 

        cast( {{ dbt_utils.date_trunc('day', 'updated_at') }} as date) as valid_starting_on

    from combine_field_history

),

surrogate_key as (

    select 
    *,
    {{ dbt_utils.surrogate_key(['field_id','issue_id', 'valid_starting_at']) }} as combined_history_id

    from get_valid_dates

)

select * from surrogate_key