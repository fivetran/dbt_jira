with epic as (

    select *
    from {{ ref('jira__epic') }}
),

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

    select
        field_history.issue_id,
        last_value(field_history.value respect nulls) over(partition by issue_id order by updated_at asc) as epic_issue_id

    from field_history
    join epic_field using (field_id)
),

grab_epic_name as (

    select 
        last_epic_link.issue_id,
        last_epic_link.epic_issue_id,

        issue_parents.issue_name as parent_issue,
        issue_parents.parent_issue_key,
        true as parent_is_epic
        
    from last_epic_link 
        join issue_parents on last_epic_link.epic_issue_id = issue_parents.issue_id
),

issue_epics as (

    select 
        issue_parents.issue_id,
        {# issue_parents.issue_type, #}
        issue_parents.parent_issue_key,
        coalesce(issue_parents.parent_issue_id, last_epic_link.epic_issue_id) as parent_issue_id,
        coalesce(issue_parents.parent_issue_name, last_epic_link.epic_name) as parent_issue_name,
        issue_parents.parent_is_epic or coalesce(last_epic_link.parent_is_epic, false) as parent_is_epic

    from issue_parents

    left join last_epic_link using(issue_id)

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