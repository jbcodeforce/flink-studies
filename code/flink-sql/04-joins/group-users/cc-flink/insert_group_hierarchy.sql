insert into group_hierarchy (id, group_name, item_name, item_type, created_at) values 
(1, 'region_1', CAST(NULL AS STRING), 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:00')),
(2, 'region_1',  'hospital_west', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:10')),
(3, 'region_1',  'hospital_east', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:10')),
(4, 'hospital_west',  'department_1', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:20')),
(5, 'hospital_east',  'department_11', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:20')),
(6, 'hospital_west',  'nurses_gp_1', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:20')),
(7, 'department_1',  'nurses_gp_2', 'GROUP', TO_TIMESTAMP('2021-01-01 00:00:20')),
(8, 'department_1',  'Julie', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:30')),
(9, 'nurses_gp_1',  'Himani', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40')),
(10, 'nurses_gp_1',  'Laura', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40')),
(11,'nurses_gp_2', 'Bratt', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40')),
(12, 'nurses_gp_2', 'Caroll', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40')),
(13, 'nurses_gp_2', 'Lucy', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40')),
(14, 'nurses_gp_2', 'Mary', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:40'));


-- Demonstrate adding person into a group impact aggregation.
insert into department_hierarchy (id, group_name, item_name, item_type, created_at) values 
(15, 'department_11', 'Paul', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:50')),
(16, 'department_11', 'Julie', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:50')),
(17, 'nurses_gp_2', 'Bob', 'PERSON', TO_TIMESTAMP('2021-01-01 00:00:50'));