with issue as (

    select * 
    from {{ ref('jira__issue_enhanced') }}
    where project_id is not null
),

-- Calculate median durations for CLOSED/RESOLVED issues only
-- Filtering to only resolved issues with non-null durations prevents Redshift percentile errors when a project has no closed issues (which would create all-NULL partitions)
calculate_closed_issue_medians as (

    select
        project_id,
        source_relation,
        -- Median time from creation to resolution for completed issues
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(open_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='project_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_close_time_seconds,
        -- Median assignment duration for completed issues
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(any_assignment_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='project_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_assigned_close_time_seconds
    from issue
    where resolved_at is not null
        and open_duration_seconds is not null

    {% if target.type == 'postgres' %} group by project_id, source_relation {% endif %}
),

-- Calculate median durations for OPEN/UNRESOLVED issues only
-- Filtering to only open issues with non-null durations prevents Redshift percentile errors when a project has no open issues (which would create all-NULL partitions)
calculate_open_issue_medians as (

    select
        project_id,
        source_relation,
        -- Median age of issues still open (time since creation)
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(open_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='project_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_age_currently_open_seconds,
        -- Median assignment duration for issues still open
        round(cast({{ fivetran_utils.percentile(
            percentile_field='cast(any_assignment_duration_seconds as ' ~ dbt.type_numeric() ~ ')',
            partition_field='project_id',
            percent='0.5'
        ) }} as {{ dbt.type_numeric() }}), 0) as median_age_currently_open_assigned_seconds
    from issue
    where resolved_at is null
        and open_duration_seconds is not null

    {% if target.type == 'postgres' %} group by project_id, source_relation {% endif %}
),

-- Combine closed and open issue medians
-- Using FULL OUTER JOIN ensures we get results for projects that have:
-- - Only closed issues (no current open work)
-- - Only open issues (no historical completions)
-- - Both closed and open issues
-- This prevents the Redshift "Invalid input" error that occurred when projects had no data for one of the median calculations
median_metrics as (

    select
        coalesce(closed_medians.project_id, open_medians.project_id) as project_id,
        coalesce(closed_medians.source_relation, open_medians.source_relation) as source_relation,
        closed_medians.median_close_time_seconds,
        open_medians.median_age_currently_open_seconds,
        closed_medians.median_assigned_close_time_seconds,
        open_medians.median_age_currently_open_assigned_seconds
    from calculate_closed_issue_medians as closed_medians
    full outer join calculate_open_issue_medians as open_medians
        on closed_medians.project_id = open_medians.project_id
        and closed_medians.source_relation = open_medians.source_relation

    {{ dbt_utils.group_by(6) }}
),


-- get appropriate counts + sums to calculate averages
project_issues as (

    select
        project_id,
        source_relation,
        sum(case when resolved_at is not null then 1 else 0 end) as count_closed_issues,
        sum(case when resolved_at is null then 1 else 0 end) as count_open_issues,
        -- using the below to calculate averages
        -- assigned issues
        sum(case when resolved_at is null and assignee_user_id is not null then 1 else 0 end) as count_open_assigned_issues,
        sum(case when resolved_at is not null and assignee_user_id is not null then 1 else 0 end) as count_closed_assigned_issues,
        -- close time
        sum(case when resolved_at is not null then open_duration_seconds else 0 end) as sum_close_time_seconds,
        sum(case when resolved_at is not null then any_assignment_duration_seconds else 0 end) as sum_assigned_close_time_seconds,
        -- age of currently open tasks
        sum(case when resolved_at is null then open_duration_seconds else 0 end) as sum_currently_open_duration_seconds,
        sum(case when resolved_at is null then any_assignment_duration_seconds else 0 end) as sum_currently_open_assigned_duration_seconds
    from issue

    group by 1, 2
),

calculate_avg_metrics as (

    select
        project_id,
        source_relation,
        count_closed_issues,
        count_open_issues,
        count_open_assigned_issues,
        case when count_closed_issues = 0 then 0 
            else round(cast(sum_close_time_seconds * 1.0 / count_closed_issues  as {{ dbt.type_numeric() }} ), 0) end as avg_close_time_seconds,
        case when count_closed_assigned_issues = 0 then 0 
            else round(cast(sum_assigned_close_time_seconds * 1.0 / count_closed_assigned_issues  as {{ dbt.type_numeric() }} ), 0) end as avg_assigned_close_time_seconds,
        case when count_open_issues = 0 then 0 
            else round(cast(sum_currently_open_duration_seconds * 1.0 / count_open_issues as {{ dbt.type_numeric() }} ), 0) end as avg_age_currently_open_seconds,
        case when count_open_assigned_issues = 0 then 0 
            else round(cast(sum_currently_open_assigned_duration_seconds * 1.0 / count_open_assigned_issues as {{ dbt.type_numeric() }} ), 0) end as avg_age_currently_open_assigned_seconds
    from project_issues
),

-- join medians and averages + convert to days
join_metrics as (

    select
        calculate_avg_metrics.*,
        -- there are 86400 seconds in a day
        round(cast(calculate_avg_metrics.avg_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_close_time_days,
        round(cast(calculate_avg_metrics.avg_assigned_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_assigned_close_time_days,
        round(cast(calculate_avg_metrics.avg_age_currently_open_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_age_currently_open_days,
        round(cast(calculate_avg_metrics.avg_age_currently_open_assigned_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as avg_age_currently_open_assigned_days,
        median_metrics.median_close_time_seconds, 
        median_metrics.median_age_currently_open_seconds,
        median_metrics.median_assigned_close_time_seconds,
        median_metrics.median_age_currently_open_assigned_seconds,
        round(cast(median_metrics.median_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_close_time_days,
        round(cast(median_metrics.median_age_currently_open_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_age_currently_open_days,
        round(cast(median_metrics.median_assigned_close_time_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_assigned_close_time_days,
        round(cast(median_metrics.median_age_currently_open_assigned_seconds / 86400.0 as {{ dbt.type_numeric() }} ), 0) as median_age_currently_open_assigned_days
    from calculate_avg_metrics
    left join median_metrics
        on calculate_avg_metrics.project_id = median_metrics.project_id
        and calculate_avg_metrics.source_relation = median_metrics.source_relation
)

select * 
from join_metrics