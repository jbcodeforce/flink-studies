select 
    u.*,
    g.group_name
from src_users u
join src_groups g on u.group_id = g.id