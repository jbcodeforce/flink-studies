insert into dim_group_users
with depts as 
(
  SELECT 
      d.group_name AS root_group,
      p.item_name AS person_name,
      p.created_at
  FROM group_hierarchy d
  LEFT JOIN group_hierarchy p 
      ON d.item_name = p.group_name OR d.group_name = p.group_name
  WHERE p.item_type = 'PERSON'
)
select 
  root_group,
  ARRAY_AGG(distinct person_name) as persons
from depts
group by root_group


---
with depts as 
(
  SELECT 
      l.group_name AS group_name,
      r.item_name AS child_name
  FROM group_hierarchy l
  LEFT JOIN group_hierarchy r 
      ON r.group_name IS NOT NULL AND (l.item_name = r.group_name OR l.group_name = r.group_name)
  WHERE r.item_type = 'GROUP'
)
select 
  group_name,
  ARRAY_AGG(distinct child_name) as groups
from depts
group by group_name
