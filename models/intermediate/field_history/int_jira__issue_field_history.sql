{{ config(materialized='table') }}

with field_history as (

    select *
    from {{ var('issue_field_history') }}
    
), 

fields as (
      
    select *
    from {{ var('field') }}

), 

joined as (
  
  select
    field_history.*,
    lower(fields.field_name) as field_name
    {# , {{ dbt_utils.generate_surrogate_key(['field_id', 'issue_id', 'updated_at'])}} as unique_key #}

  from field_history
  join fields
    on fields.field_id = field_history.field_id

)

select *
from joined