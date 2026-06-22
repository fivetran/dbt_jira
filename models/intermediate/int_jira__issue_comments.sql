{{ config(enabled=var('jira_include_comments', True)) }}

{% set comment_render = "cast(comment.created_at as " ~ dbt.type_string() ~ ") || '  -  ' || jira_user.user_display_name || ':  ' || comment.body" %}

-- Character limit of 16MB for Snowflake and BigQuery, which error when the conversation exceeds the char limit for a string. Redshift is excluded (see DECISIONLOG for details).
{% set conversation_char_limit = var('jira_conversation_char_limit', 16777216) %}

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
    {%- if target.type in ['snowflake', 'bigquery'] %}
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
