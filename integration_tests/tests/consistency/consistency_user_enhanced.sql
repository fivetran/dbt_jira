
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

{# Exclude columns that depend on calculations involving the current time in seconds or aggregate strings in a random order, as they will differ between runs. #}
{% set exclude_columns = ['avg_age_currently_open_seconds', 'median_age_currently_open_seconds', 'projects'] %}

with prod as (
    select {{ dbt_utils.star(from=ref('jira__user_enhanced'), except=exclude_columns) }}
    from {{ target.schema }}_jira_prod.jira__user_enhanced
),

dev as (
    select {{ dbt_utils.star(from=ref('jira__user_enhanced'), except=exclude_columns) }}
    from {{ target.schema }}_jira_dev.jira__user_enhanced
),

prod_not_in_dev as (
    -- rows from prod not found in dev
    select * from prod
    except distinct
    select * from dev
),

dev_not_in_prod as (
    -- rows from dev not found in prod
    select * from dev
    except distinct
    select * from prod
),

final as (
    select
        *,
        'from prod' as source
    from prod_not_in_dev

    union all -- union since we only care if rows are produced

    select
        *,
        'from dev' as source
    from dev_not_in_prod
)

select *
from final