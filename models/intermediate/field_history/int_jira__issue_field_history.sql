with field_history as (

    select *
    from {{ ref('stg_jira__issue_field_history') }}
    
), 

fields as (
      
    select *
    from {{ ref('stg_jira__field') }}

), 

joined as (
  
  select
    field_history.*,
    lower(fields.field_name) as field_name

  from field_history
  join fields
    on fields.field_id = field_history.field_id

)

select *
from joined