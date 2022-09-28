{% macro scrub_column_list( column_list ) %}

    {% set ret = [] %}
    {% for col in column_list 
        {% ret.append(col) %}
    {% endfor %}

    {{ return(ret) }}
{% endmacro %}