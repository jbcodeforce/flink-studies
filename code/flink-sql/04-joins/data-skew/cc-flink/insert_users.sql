create table src_users 
(
    id int primary key not enforced,
    group_id int,
    name string,
    email string,
    created_at timestamp
) distributed by (id) into 1 buckets;

insert into src_users (id, group_id, name, email, created_at) values  
(1, 1, 'John Doe', 'john.doe@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(2, 2, 'Jane Smith', 'jane.smith@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(3, 3, 'Jim Beam', 'jim.beam@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(4, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(5, 4, 'Jack Daniels', 'jack.daniels@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(6, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(7, 5, 'Jack Daniels', 'jack.daniels@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(8, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(9, 3, 'Jack Daniels', 'jack.daniels@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(10, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(11, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(12, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(13, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(14, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(15, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(16, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(17, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00') ),
(18, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(19, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00')),
(20, 1, 'Jill Johnson', 'jill.johnson@example.com', TO_TIMESTAMP('2021-01-01 00:00:00'))
;