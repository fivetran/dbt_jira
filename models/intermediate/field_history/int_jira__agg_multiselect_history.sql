{{
    config(
        materialized='incremental',
        partition_by = {'field': 'date_day', 'data_type': 'date'},
        unique_key='batch_id'
    )
}}

with issue_multiselect_history as (

    select *
    from {{ var('issue_multiselect_history') }}

    {% if is_incremental() %}
    -- always refresh the most recent day of data
    where cast( {{ dbt_utils.dateadd('day', -1, 'updated_at') }} as date) >= (select max(date_day) from {{ this }})
    {% endif %}

),

batch_updates as (

    select 
        *,
        {{ dbt_utils.surrogate_key(['field_id', 'issue_id', 'updated_at']) }} as batch_id

    from issue_multiselect_history 
),

consolidate_batches as (

    select 
        field_id,
        issue_id,
        updated_at,
        batch_id,
        cast( {{ dbt_utils.date_trunc('day', 'updated_at') }} as date) as date_day,

        -- if the field refers to an object captured in a table elsewhere (ie sprint, users, field_option for custom fields) 
        -- the value is actually a foreign key to that table
        {{ fivetran_utils.string_agg('batch_updates.field_value', "', '") }} as field_values 

    from batch_updates

    group by 1,2,3,4,5
)

select *
from consolidate_batches