with issue as (

    select *
    from {{ ref('jira__issue_enhanced') }} 
    where assignee_user_id is not null
),

-- Calculate median assignment durations for CLOSED/RESOLVED issues only
-- These represent historical user performance: "how long did this user typically take to complete assigned issues?"
-- Filtering to only resolved issues with non-null durations prevents Redshift percentile errors
-- when a user has no closed issues (which would create all-NULL partitions)
calculate_closed_issue_medians as (

    select
        assignee_user_id as user_id,
        source_relation,
        -- Median time this user took to complete assigned issues
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(last_assignment_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='assignee_user_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_close_time_seconds
    from issue
    where resolved_at is not null
        and last_assignment_duration_seconds is not null
    {% if target.type == 'postgres' %} group by 1, 2 {% endif %}
),

-- Calculate median assignment durations for OPEN/UNRESOLVED issues only
-- These represent current user workload aging: "how long has this user been working on open issues?"
-- Filtering to only open issues with non-null durations prevents Redshift percentile errors
-- when a user has no open issues (which would create all-NULL partitions)
calculate_open_issue_medians as (

    select
        assignee_user_id as user_id,
        source_relation,
        -- Median age of issues currently assigned to this user
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(last_assignment_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='assignee_user_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_age_currently_open_seconds
    from issue
    where resolved_at is null
        and last_assignment_duration_seconds is not null
    {% if target.type == 'postgres' %} group by 1, 2 {% endif %}
),

-- Combine closed and open issue medians for each user
-- Using FULL OUTER JOIN ensures we get results for users that have:
-- - Only closed issues (completed work but no current assignments)
-- - Only open issues (current assignments but no historical completions)
-- - Both closed and open issues
-- This prevents the Redshift "Invalid input" error that occurred when users
-- had no data for one of the median calculations
median_metrics as (

    select
        coalesce(closed_medians.user_id, open_medians.user_id) as user_id,
        coalesce(closed_medians.source_relation, open_medians.source_relation) as source_relation,
        closed_medians.median_close_time_seconds,
        open_medians.median_age_currently_open_seconds
    from calculate_closed_issue_medians as closed_medians
    full outer join calculate_open_issue_medians as open_medians
        on closed_medians.user_id = open_medians.user_id
        and closed_medians.source_relation = open_medians.source_relation

    {{ dbt_utils.group_by(4) }}
),


user_issues as (

    select
        assignee_user_id as user_id,
        source_relation,
        sum(case when resolved_at is not null then 1 else 0 end) as count_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as count_open_issues,
        sum(case when resolved_at is not null then last_assignment_duration_seconds else 0 end) as sum_close_time_seconds,
        sum(case when resolved_at is null then last_assignment_duration_seconds else 0 end) as sum_current_open_seconds
    from issue
    group by 1, 2
),

calculate_avg_metrics as (

    select
        user_id,
        source_relation,
        count_closed_issues,
        count_open_issues,
        case when count_closed_issues = 0 then 0 else
            round(cast(sum_close_time_seconds * 1.0 / count_closed_issues as {{ dbt.type_numeric() }} ), 0) end as avg_close_time_seconds,
        case when count_open_issues = 0 then 0 else
            round(cast(sum_current_open_seconds * 1.0 / count_open_issues as {{ dbt.type_numeric() }} ), 0) end as avg_age_currently_open_seconds
    from user_issues
),

join_metrics as (

    select
        calculate_avg_metrics.*,
        round(cast(calculate_avg_metrics.avg_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_close_time_days,
        round(cast(calculate_avg_metrics.avg_age_currently_open_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_age_currently_open_days,
        median_metrics.median_close_time_seconds,
        median_metrics.median_age_currently_open_seconds,
        round(cast(median_metrics.median_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_close_time_days,
        round(cast(median_metrics.median_age_currently_open_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_age_currently_open_days 
    from calculate_avg_metrics
    left join median_metrics on
        calculate_avg_metrics.user_id = median_metrics.user_id
        and calculate_avg_metrics.source_relation = median_metrics.source_relation
)

select * 
from join_metrics