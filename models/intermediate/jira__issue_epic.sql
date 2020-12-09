with epic as (
    -- just a subset of issues with issue_type = 'epic'

    select *
    from {{ ref('jira__epic') }}
),

-- issue-epic relationships are either captured via the issue's parent_issue_id,
-- or through the 'Epic Link' field. todo: figure out the pattern behind this...
-- note: Fivetran plans to fix this because that's wonky!
issue_parents as (

    select *
    from {{ ref('jira__issue_type_parents') }}

),

field_history as (

    select *
    from {{ var('issue_field_history') }}
    
),

-- just grabbing the field id for epics from classic projects
epic_field as (

    select field_id
        
    from {{ var('field') }}
    where lower(field_name) like 'epic%link'
),

last_epic_link as (

    select issue_id, epic_issue_id 
    
    from (

    select
        field_history.issue_id,
        cast(last_value(field_history.field_value respect nulls) over(partition by issue_id order by updated_at asc) as {{ dbt_utils.type_int() }} ) as epic_issue_id

    from field_history
    join epic_field using (field_id) )

    group by 1,2
),

grab_epic_name as (

    select 
        last_epic_link.issue_id,
        last_epic_link.epic_issue_id,

        issue_parents.issue_name as epic_name,
        issue_parents.issue_key as epic_issue_key,

        true as parent_is_epic
        
    from last_epic_link 
    -- grab epic's issue attributes
        join issue_parents on last_epic_link.epic_issue_id = issue_parents.issue_id
),

issue_epics as (

    select 
        issue_parents.issue_id,
        {# issue_parents.issue_type, #}
        coalesce(issue_parents.parent_issue_key, grab_epic_name.epic_issue_key) as parent_issue_key,

        coalesce(issue_parents.parent_issue_id, grab_epic_name.epic_issue_id) as parent_issue_id,
        coalesce(issue_parents.parent_issue_name, grab_epic_name.epic_name) as parent_issue_name,
        issue_parents.parent_is_epic or coalesce(grab_epic_name.parent_is_epic, false) as parent_is_epic

    from issue_parents

    left join grab_epic_name 
        on issue_parents.issue_id = grab_epic_name.issue_id

),

final as (

    select
        issue_id,
        parent_issue_id as epic_issue_id,
        parent_issue_name as epic_name,
        parent_issue_key as epic_key

    from issue_epics 

    where parent_is_epic
)

select * from final