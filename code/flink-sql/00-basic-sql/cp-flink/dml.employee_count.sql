alter table employee_count set ('changelog-mode' = 'append');
insert into `employee-count`
with deduplicated_employees as (
    select * from (
        select *,
        ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id DESC) as row_num
        from employees
    ) where row_num = 1
)
select coalesce(dept_id, 0) as dept_id, count(*) as emp_count from deduplicated_employees group by dept_id;
