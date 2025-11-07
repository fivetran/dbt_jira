{{ config(enabled=var('jira_using_priorities', True)) }}

{{
    jira.jira_union_connections(
        connection_dictionary='jira_sources',
        single_source_name='jira',
        single_table_name='priority'
    )
}}
