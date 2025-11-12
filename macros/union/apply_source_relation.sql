{% macro apply_source_relation() -%}

{{ adapter.dispatch('apply_source_relation', 'jira') () }}

{%- endmacro %}

{% macro default__apply_source_relation() -%}

{% if var('jira_sources', []) != [] %}
, _dbt_source_relation as source_relation
{% else %}
, '{{ var("jira_database", target.database) }}' || '.'|| '{{ var("jira_schema", "jira") }}' as source_relation
{% endif %}

{%- endmacro %}