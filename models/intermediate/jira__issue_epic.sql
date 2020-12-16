-- just a subset of issues with issue_type = 'epic'
with epic as (
    
    select *
    from {{ ref('jira__epic') }}
),

-- issue-epic relationships are either captured via the issue's parent_issue_id (next-gen projects)
-- or through the 'Epic Link' field (classic projects)
issue_parents as (

    select *
    from {{ ref('jira__issue_type_parents') }}

),

field_history as (

    select *
    from {{ var('issue_field_history') }}
    
),

-- grabbing the field id for epics from classic projects, because epic link is technically a custom field and therefore has a custom field id
epic_field as (

    -- field_id is turning into an int in AWS...
    select field_id
        
    from {{ var('field') }}
    where lower(field_name) like 'epic%link'
),

-- only grab history pertaining to epic links
epic_history as (

    select field_history.*

    from field_history
    join epic_field using (field_id) 
),

last_epic_link as (

    select issue_id, epic_issue_id 
    
    from (

        select
            issue_id,
            cast(field_value as {{ dbt_utils.type_int() }} ) as epic_issue_id,

            row_number() over (
                    partition by issue_id order by updated_at desc
                    ) as row_num

            from epic_history
        ) 
    where row_num = 1
),

grab_epic_name as (

    select 
        last_epic_link.issue_id,
        last_epic_link.epic_issue_id,

        issue_parents.issue_name as epic_name,
        issue_parents.issue_key as epic_issue_key
        
    from last_epic_link 
    -- to grab each epic's issue attributes
        join issue_parents on last_epic_link.epic_issue_id = issue_parents.issue_id
),

issue_epics as (

    select 
        issue_parents.issue_id,
        coalesce(issue_parents.parent_issue_key, grab_epic_name.epic_issue_key) as parent_issue_key,

        coalesce(issue_parents.parent_issue_id, grab_epic_name.epic_issue_id) as parent_issue_id,
        coalesce(issue_parents.parent_issue_name, grab_epic_name.epic_name) as parent_issue_name,
        issue_parents.parent_is_epic or grab_epic_name.issue_id is not null as parent_is_epic

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