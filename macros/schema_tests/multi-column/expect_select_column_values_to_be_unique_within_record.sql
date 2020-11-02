{% macro test_expect_select_column_values_to_be_unique_within_record(model, 
                                                    column_list,
                                                    quote_columns=False,
                                                    ignore_row_if="all_values_are_missing",
                                                    partition_column=None,
                                                    partition_filter=None
                                                    ) %}

{% if not quote_columns %}
    {%- set columns=column_list %}
{% elif quote_columns %}
    {%- set columns=[] %}
        {% for column in column_list -%}
            {% set columns = columns.append( adapter.quote(column) ) %}
        {%- endfor %}
{% else %}
    {{ exceptions.raise_compiler_error(
        "`quote_columns` argument for unique_combination_of_columns test must be one of [True, False] Got: '" ~ quote_columns ~"'.'"
    ) }}
{% endif %}

with column_values as (

    select
        row_number() over() as row_index,
        {% for column in columns -%}
        {{ column }}{% if not loop.last %},{% endif %}
        {%- endfor %}
    from {{ model }}
    where 1=1
    {% if partition_column and partition_filter %}
        and {{ partition_column }} {{ partition_filter }}
    {% endif %}
    {% if ignore_row_if == "all_values_are_missing" %}
        and 
        (
            {% for column in columns -%}
            {{ column }} is not null{% if not loop.last %} and {% endif %}
            {%- endfor %}
        )
    {% elif ignore_row_if == "any_value_is_missing" %}
        and
        (
            {% for column in columns -%}
            {{ column }} is not null{% if not loop.last %} or {% endif %}
            {%- endfor %}
        )
    {% endif %}

),
unpivot_columns as (

    {% for column in columns %}
    select row_index, '{{ column }}' as column_name, {{ column }} as column_value from column_values
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
),
validation_errors as (
    
    select
        row_index,
        count(distinct column_value) as column_values
    from unpivot_columns
    group by 1
    having count(distinct column_value) < {{ columns | length }}

) 
select count(*) from validation_errors
{% endmacro %}