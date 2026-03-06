-- pkg_a has same expected_ts. pkg_b has different expected_ts. pkg_c has no new event.
insert into package_events values
('pkg_a', TIMESTAMP '2025-03-04 10:00:00', 'enroute', TIMESTAMP '2025-03-04 15:30:00', 'new_eta', 'package a for customer c1'),
('pkg_b', TIMESTAMP '2025-03-04 10:00:00', 'enroute', TIMESTAMP '2025-03-04 15:40:00', 'new_eta', 'package b for customer c2'),
('pkg_c', TIMESTAMP '2025-03-04 10:00:00', 'enroute', TIMESTAMP '2025-03-04 19:30:00', 'new_eta', 'package c for customer c3'),
('pkg_a', TIMESTAMP '2025-03-04 10:30:00', 'enroute', TIMESTAMP '2025-03-04 15:30:00', '', 'package a for customer c1'),
('pkg_b', TIMESTAMP '2025-03-04 10:30:00', 'enroute', TIMESTAMP '2025-03-04 16:30:00', 'new_eta', 'package b for customer c2 new ETA'),
('pkg_d', TIMESTAMP '2025-03-02 08:00:00', 'enroute', TIMESTAMP '2025-03-03 16:30:00', 'new_eta', 'package d for customer c4'),
('pkg_e', TIMESTAMP '2025-03-04 00:00:01', 'enroute', TIMESTAMP '2025-03-04 17:00:00', 'new_eta', 'package e for customer c5');


-- expected results 
-- ('pkg_a', TIMESTAMP '2025-03-04 10:30:00', 'enroute', TIMESTAMP '2025-03-04 15:30:00', 'new_eta','package a for customer c1')
-- ('pkg_c', TIMESTAMP '2025-03-04 10:00:00', 'enroute', TIMESTAMP '2025-03-04 19:30:00', 'new_eta', 'package c for customer c3'),
-- ('pkg_b', TIMESTAMP '2025-03-04 10:30:00', 'enroute', TIMESTAMP '2025-03-04 16:30:00', 'new_eta', 'package b for customer c2 new ETA')