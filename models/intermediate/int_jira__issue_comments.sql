{{ config(enabled=var('jira_include_comments', True)) }}

with comment as (

    select *
    from {{ ref('stg_jira__comment') }}
    order by issue_id, created_at asc
),

-- user is a reserved keyword in AWS 
jira_user as (

    select *
    from {{ ref('stg_jira__user') }}
),

agg_comments as (

    select
    comment.issue_id,
    comment.source_relation,
    count(comment.comment_id) as count_comments

    {%- if var('jira_include_conversations', False if target.type == 'redshift' else True) %}
    ,{{ fivetran_utils.string_agg(
        "comment.created_at || '  -  ' || jira_user.user_display_name || ':  ' || comment.body",
        "'\\n'" ) }} as conversation
    {% endif %}

    from comment
    inner join jira_user
        on comment.author_user_id = jira_user.user_id
        and comment.source_relation = jira_user.source_relation
    group by 1, 2
)

select * from agg_comments
