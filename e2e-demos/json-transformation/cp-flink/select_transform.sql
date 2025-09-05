-- those are examples of possible transformations:

-- create one row per equipment item
with equipment as (select e.ModelCode, e.Rate from `raw-orders` as ro
 cross join unnest(ro.Equipment) as e)

 

