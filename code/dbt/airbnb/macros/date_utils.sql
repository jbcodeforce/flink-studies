{# Portable to_date: Snowflake uses TO_DATE(), DuckDB and others use CAST(... AS DATE) #}
{% macro to_date(expr) %}
  {{ adapter.dispatch('to_date', 'airbnb_utils')(expr) }}
{% endmacro %}

{% macro default__to_date(expr) %}
  cast({{ expr }} as date)
{% endmacro %}

{% macro snowflake__to_date(expr) %}
  to_date({{ expr }})
{% endmacro %}

{# Portable dateadd one day: Snowflake uses DATEADD(day, 1, ...), DuckDB uses ... + INTERVAL 1 DAY #}
{% macro dateadd_day(date_expr) %}
  {{ adapter.dispatch('dateadd_day', 'airbnb_utils')(date_expr) }}
{% endmacro %}

{% macro default__dateadd_day(date_expr) %}
  {{ date_expr }} + interval '1 day'
{% endmacro %}

{% macro snowflake__dateadd_day(date_expr) %}
  dateadd(day, 1, {{ date_expr }})
{% endmacro %}
