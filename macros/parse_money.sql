{% macro parse_money(column) -%}
safe_cast(
    replace(replace(trim(cast({{ column }} as string)), '$', ''), ',', '') as numeric
)
{%- endmacro %}
