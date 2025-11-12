{{ config(enabled=var('jira_using_versions', True)) }}

with version as (

    select *
    from {{ ref('stg_jira__version') }}
),

version_history as (

    select *
    from {{ ref('int_jira__issue_multiselect_history') }}
    where field_id = 'versions'
        or field_id = 'fixVersions'
),

order_versions as (

    select
        *,
        -- using rank so batches stick together
        rank() over (
            partition by field_id, issue_id {{ jira.partition_by_source_relation() }}
            order by updated_at desc
            ) as row_num
    from version_history
),

latest_versions as (

    select
        field_id,
        issue_id,
        source_relation,
        updated_at,
        cast(field_value as {{ dbt.type_int() }}) as version_id
    from order_versions
    where row_num = 1
),

version_info as (

    select
        latest_versions.field_id,
        latest_versions.issue_id,
        latest_versions.source_relation,
        {{ fivetran_utils.string_agg('version.version_name', "', '") }} as versions

    from latest_versions
    join version on latest_versions.version_id = version.version_id
        and latest_versions.source_relation = version.source_relation

    group by 1,2,3
),

split_versions as (

    select
        issue_id,
        source_relation,
        case when field_id = 'versions' then versions else null end as affects_versions,
        case when field_id = 'fixVersions' then versions else null end as fixes_versions
    from version_info
),

final as (

    select
        issue_id,
        source_relation,
        max(affects_versions) as affects_versions,
        max(fixes_versions) as fixes_versions
    from split_versions
    group by 1, 2
)

select *
from final