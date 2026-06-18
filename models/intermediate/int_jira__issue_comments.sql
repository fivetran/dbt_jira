{{ config(enabled=var('jira_include_comments', True)) }}

{% set comment_render = "comment.created_at || '  -  ' || jira_user.user_display_name || ':  ' || comment.body" %}
{% set default_char_limit = 65535 if target.type == 'redshift' else 16777216 %}
{% set conversation_char_limit = var('jira_conversation_char_limit', default_char_limit) %}
{% set guard_conversation = target.type in ['snowflake', 'bigquery', 'redshift'] %}

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

    {%- if var('jira_include_conversations', target.type != 'redshift') %}
        {% if guard_conversation -%}
        , case when sum(length({{ comment_render }} || '\n')) <= {{ conversation_char_limit }}
            then {{ fivetran_utils.string_agg(comment_render, "'\\n'") }}
            else 'conversation too long to render'
        end as conversation
        {%- else %}
        , {{ fivetran_utils.string_agg(comment_render, "'\\n'") }} as conversation
        {%- endif %} 
    {% endif %}

    from comment
    inner join jira_user
        on comment.author_user_id = jira_user.user_id
        and comment.source_relation = jira_user.source_relation
    group by 1, 2
)

select * from agg_comments
