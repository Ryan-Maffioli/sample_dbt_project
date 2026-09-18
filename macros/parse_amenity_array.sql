{% macro parse_amenity_array(column) -%}
case
    when {{ column }} is null then cast(null as array<string>)
    when json_extract_string_array({{ column }}) is null then cast(null as array<string>)
    else array(
        select trim(item)
        from unnest(json_extract_string_array({{ column }})) as item
        where item is not null
          and trim(item) != ''
    )
end
{%- endmacro %}
