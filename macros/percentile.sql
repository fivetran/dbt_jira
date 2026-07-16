{% macro duckdb__percentile(percentile_field, partition_field, percent) %}

    quantile_cont({{ percentile_field }}, {{ percent }}) over (partition by {{ partition_field }})

{% endmacro %}
