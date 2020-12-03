with component as (

    select *
    from {{ var('component') }}

),

component_history as (

    select *
    from {{ var('issue_field_history') }}

    where lower(field_id) = 'components'
)
{# 
agg_components as (

    select 
    comment.issue_id,
    {{ fivetran_utils.string_agg( "comment.created_at || '  -  ' || user.user_display_name || ':  ' || comment.body", "'\\n'" ) }} as conversation

    from
    comment 
    join user on comment.author_user_id = user.user_id

    group by 1
) #}

-- todo: figure out if this is actually helpful given the nature of issue_multiselect_history
select * from component_history