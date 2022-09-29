{% macro set_safe_col_name( col_name ) %}
    -- this macro can be used to set safe column names for various database engines.
    {% set col_arry = col_name %}
    -- if the column name matches the unsafe pattern, add a leading underscore
    {% if modules.re.match('[0-9]', col_arry[0]) %}
        {% set col_name = '_' ~ col_name %}
    {% endif %}

{{ return(col_name) }}

{% endmacro %}