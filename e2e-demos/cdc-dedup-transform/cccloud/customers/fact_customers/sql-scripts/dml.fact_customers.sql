INSERT INTO fact_customers
select
    src_customers.customer_id,
    src_customers.name,
    CASE 
        WHEN src_customers.email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' 
        THEN src_customers.email 
        ELSE 'email_invalid' 
    END as email,
    src_customers.age,
    src_customers.created_at,
    src_customers.updated_at,
    src_customers.group_id
from src_customers
join dim_groups on src_customers.group_id = dim_groups.group_id;
from src_customers
join dim_groups on src_customers.group_id = dim_groups.group_id;