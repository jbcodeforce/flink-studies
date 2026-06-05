{% macro crm_create_mongodb_connection() %}
  {% if not var('crm_enable_mongodb', false) %}
    {% do return(none) %}
  {% endif %}
  {% set endpoint = var('crm_mongodb_endpoint') %}
  {% set username = var('crm_mongodb_username') %}
  {% set password = var('crm_mongodb_password') %}
  {% if endpoint == '' or username == '' or password == '' %}
    {% do exceptions.raise_compiler_error(
      'crm_enable_mongodb is true but CRM_MONGODB_ENDPOINT, CRM_MONGODB_USERNAME, or CRM_MONGODB_PASSWORD is missing'
    ) %}
  {% endif %}
  create connection mongodb_connection
    with (
      'type' = 'mongodb',
      'endpoint' = '{{ endpoint }}',
      'username' = '{{ username }}',
      'password' = '{{ password }}'
    );
{% endmacro %}
