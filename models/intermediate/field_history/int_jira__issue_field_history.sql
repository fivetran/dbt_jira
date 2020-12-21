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
    fields.field_name

  from field_history
  join fields using (field_id)

)

select *
from joined