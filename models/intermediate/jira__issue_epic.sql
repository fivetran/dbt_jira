with epic as (

    select *
    from {{ ref('jira__epic') }}
),

issue_w_parents as (

    select *
    from {{ ref('jira_issue_type_parents') }}

),

field_history as (

    select *
    from {{ var('issue_field_history') }}
    
),

-- just grabbing the field id for epics
epic_field as (

    select field_id
        
    from {{ var('field') }}
    where lower(field_name) like 'epic%link'
),

epic_field_history as (

    select
    from field_history
    join epic_field using (field_id)
)

