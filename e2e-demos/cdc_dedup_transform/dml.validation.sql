-- route to business DLQ
inset into data_exception
select * from src_customers 
    where email is null 
        or email = '' or not REGEXP(email,'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') 
        or age is not null and age < 0;