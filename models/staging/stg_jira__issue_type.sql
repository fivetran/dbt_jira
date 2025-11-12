with base as (

    select * from 
    {{ ref('stg_jira__issue_type_tmp') }}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_jira__issue_type_tmp')),
                staging_columns=get_issue_type_columns()
            )
        }}
        {{ jira.apply_source_relation() }}
    from base
),

final as (

    select
        source_relation,
        description,
        id as issue_type_id,
        name as issue_type_name,
        subtask as is_subtask,
        _fivetran_synced
    from fields
)

select * 
from final