{% macro parse_tf_boolean(column) -%}
case
    when lower(trim(cast({{ column }} as string))) in ('t', 'true', '1') then true
    when lower(trim(cast({{ column }} as string))) in ('f', 'false', '0') then false
    else cast(null as bool)
end
{%- endmacro %}
