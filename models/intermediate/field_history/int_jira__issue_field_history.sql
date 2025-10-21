with field_history as (

    select *
    from {{ ref('stg_jira__issue_field_history') }}
    
), 

fields as (
      
    select *
    from {{ ref('stg_jira__field') }}

), 

{% if var('jira_using_teams', True) %}
teams as ( 

    select * 
    from {{ ref('stg_jira__team') }} 
),
{% endif %}

joined as (
  
  select
    field_history.field_id,
    field_history.issue_id,
    field_history.updated_at,
    {% if var('jira_using_teams', True) %}
    -- if the field is 'team', we want to replace the value with the team name
    -- otherwise, just use the value as is
    case when lower(fields.field_name) = 'team' then teams.team_name
         else field_history.field_value end as field_value,
    {% else %}
    field_history.field_value,
    {% endif %}
    lower(fields.field_name) as field_name,
    field_history.is_active,
    field_history.author_id,
    field_history._fivetran_synced

  from field_history
  join fields
    on fields.field_id = field_history.field_id
  {% if var('jira_using_teams', True) %}
  left join teams on lower(fields.field_name) = 'team'
  and cast(field_history.field_value as {{ dbt.type_string() }}) = cast(teams.team_id as {{ dbt.type_string() }})
  {% endif %}

)

select *
from joined 