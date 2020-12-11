-- todo: make this incremental prob 
with issue_multiselect_history as (

    select *
    from {{ var('issue_multiselect_history') }}

    where field_value != '' -- this seems to never be helpful
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

        -- if the field refers to an object captured in a table elsewhere (ie sprint, users, field_option for custom fields) 
        -- the value is actually a foreign key to that table
        {{ fivetran_utils.string_agg('batch_updates.field_value', "', '") }} as field_values 

    from batch_updates

    group by 1,2,3,4
)

select *
from consolidate_batches