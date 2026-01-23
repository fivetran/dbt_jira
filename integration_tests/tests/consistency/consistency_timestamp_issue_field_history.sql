
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- source_relation is excluded as it will differ between prod and dev schemas
with prod as (
    select
        valid_from,
        issue_id,
        status,
        status_id,
        author_id,
        sprint,
        story_points,
        story_point_estimate 
    from {{ target.schema }}_jira_prod.jira__timestamp_issue_field_history
),

dev as (
    select
        valid_from,
        issue_id,
        status,
        status_id,
        author_id,
        sprint,
        story_points,
        story_point_estimate 
    from {{ target.schema }}_jira_dev.jira__timestamp_issue_field_history
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