-- second highest salary from employees table
SELECT employee_id, 
       salary 
FROM   employees 
WHERE  salary = (SELECT Max(salary) 
                 FROM   employees 
                 WHERE  salary < (SELECT Max(salary) 
                                  FROM   employees)); 