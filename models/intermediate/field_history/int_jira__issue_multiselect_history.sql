with issue_multiselect_history as (

    select *
    from {{ var('issue_multiselect_history') }}
    
), 

fields as (
      
    select *
    from {{ var('field') }}

), 

joined as (
  
  select
    issue_multiselect_history.*,
    fields.field_name

  from issue_multiselect_history
  join fields using (field_id)

)

select *
from joined