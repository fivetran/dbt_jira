-- todo: make this incremental? 
with issue_multiselect_history as (

    select *
    from {{ var('issue_multiselect_history') }}

    where field_value != '' -- todo: should i do this?
),

batch_updates as (

    select 
        *,
        {{ dbt_utils.surrogate_key(['field_id', 'issue_id', 'updated_at']) }} as batch_id

    from issue_multiselect_history 
),

{# grab_actual_field_values as (
-- should i create a field_option table that has it all (field_option does not include components or sprints)
    select
        *
    from batch_updates
), #}

consolidate_batches as (

    select 
        field_id,
        issue_id,
        updated_at,
        batch_id,

        {{ fivetran_utils.string_agg('batch_updates.field_value', "', '") }} as field_values 
        -- note: these are the IDs pointing to either the ID of field_option, component, sprint, 

    from batch_updates

    group by 1,2,3,4
)

select *
from consolidate_batches