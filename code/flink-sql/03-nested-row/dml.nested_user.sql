SELECT
  t.user_data.user_id,
  t.user_data.user_agent,
  t.user_data.*
FROM nested_user_clicks as t;