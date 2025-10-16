with field_history as (

    select *
    from {{ ref('stg_jira__issue_field_history') }}
    
), 

fields as (
      
    select *
    from {{ ref('stg_jira__field') }}

), 

team as (

    select * 
    from {{ ref('stg_jira__team') }}
),

joined as (
  
  select
    field_history.field_id,
    field_history.issue_id,
    field_history.updated_at,
    -- if the field is 'team', we want to replace the value with the team name
    -- otherwise, just use the value as is
    case when lower(fields.field_name) = 'team' then team.team_name
         else field_history.field_value end as field_value,
    lower(fields.field_name) as field_name,
    field_history.is_active,
    field_history._fivetran_synced

  from field_history
  join fields
    on fields.field_id = field_history.field_id
  left join team on lower(fields.field_name) = 'team'
  and cast(field_history.field_value as {{ dbt.type_string() }}) = cast(team.team_id as {{ dbt.type_string() }})

)

select *
from joined