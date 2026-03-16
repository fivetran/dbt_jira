{%- macro convert_string_to_numeric(column) -%}
{{ return(adapter.dispatch('convert_string_to_numeric', 'jira')(column)) }}
{%- endmacro -%}

{%- macro default__convert_string_to_numeric(column) -%}
cast(replace({{ column }}, ',', '') as {{ dbt.type_numeric() }})
{%- endmacro -%}

{%- macro bigquery__convert_string_to_numeric(column) -%}
cast(regexp_extract(replace({{ column }}, ',', ''), r'-?\d+(?:\.\d+)?') as {{ dbt.type_numeric() }})
{%- endmacro -%}

{%- macro snowflake__convert_string_to_numeric(column) -%}
cast(regexp_substr(replace({{ column }}, ',', ''), '-?[0-9]+(\\.[0-9]+)?') as {{ dbt.type_numeric() }})
{%- endmacro -%}

{%- macro postgres__convert_string_to_numeric(column) -%}
cast(substring(replace({{ column }}, ',', '') from '(-?[0-9]+(\.[0-9]+)?)') as {{ dbt.type_numeric() }})
{%- endmacro -%}

{%- macro redshift__convert_string_to_numeric(column) -%}
cast(regexp_substr(replace({{ column }}, ',', ''), '(-?[0-9]+(\.[0-9]+)?)') as {{ dbt.type_numeric() }})
{%- endmacro -%}

{%- macro spark__convert_string_to_numeric(column) -%}
cast(regexp_extract(replace({{ column }}, ',', ''), '(-?\\d+(\\.\\d+)?)', 0) as {{ dbt.type_numeric() }})
{%- endmacro -%}
