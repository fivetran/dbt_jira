{% macro jira_lookback(from_date, datepart, interval, safety_date='2010-01-01') %}

{{ adapter.dispatch('jira_lookback', 'jira') (from_date, datepart, interval, safety_date='2010-01-01') }}

{%- endmacro %}

{% macro default__jira_lookback(from_date, datepart, interval, safety_date='2010-01-01')  %}

    coalesce(
        (select {{ dbt.dateadd(datepart=datepart, interval=-interval, from_date_or_timestamp=from_date) }} 
            from {{ this }}), 
        {{ "'" ~ safety_date ~ "'" }}
        )

{% endmacro %}