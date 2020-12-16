with comment as (

    select *
    from {{ var('comment') }}

    order by issue_id, created_at asc

),

user as (

    select *
    from {{ var('user') }}
),

agg_comments as (

    select 
    comment.issue_id,
    {{ fivetran_utils.string_agg( "comment.created_at || '  -  ' || user.user_display_name || ':  ' || comment.body", "'\\n'" ) }} as conversation,
    count(distinct comment.comment_id) as n_comments

    from
    comment 
    join user on comment.author_user_id = user.user_id

    group by 1
)

select * from agg_comments