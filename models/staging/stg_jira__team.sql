{{ config(enabled=var('jira_using_teams', True)) }}

with base as (

    select * 
    from {{ ref('stg_jira__team_tmp') }}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_jira__team_tmp')),
                staging_columns=get_team_columns()
            )
        }}
    from base
),

final as (
    
    select 
        cast(id as {{ dbt.type_string() }}) as team_id,
        is_shared,
        is_visible,
        name as team_name,
        title as team_title,
        _fivetran_synced
    from fields
)

select * 
from final
