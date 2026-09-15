INSERT INTO raw_tickets (case_id, description, priority, owner, testresults, creation_ts)
VALUES
  ('case_001', 'Login failure on checkout',        1,              'alice',  'PASS',              TO_TIMESTAMP_LTZ(1700000000, 3)),
  ('case_002', CAST(NULL AS STRING),               2,              'bob',    CAST(NULL AS STRING), TO_TIMESTAMP_LTZ(1700001000, 3)),
  ('case_003', 'Timeout on payment service',       CAST(NULL AS INT), 'carol', 'FAIL',            TO_TIMESTAMP_LTZ(1700002000, 3)),
  ('case_004', 'DB connection pool exhausted',     3,              'alice',  CAST(NULL AS STRING), TO_TIMESTAMP_LTZ(1700003000, 3)),
  ('case_005', CAST(NULL AS STRING),               CAST(NULL AS INT), CAST(NULL AS STRING), 'PASS', TO_TIMESTAMP_LTZ(1700004000, 3)),
  ('case_006', 'Null pointer in order service',    1,              'dave',   'FAIL',              TO_TIMESTAMP_LTZ(1700005000, 3)),
  ('case_007', 'Memory leak detected',             2,              CAST(NULL AS STRING), 'PASS',  TO_TIMESTAMP_LTZ(1700006000, 3)),
  ('case_008', 'API rate limit exceeded',          3,              'bob',    CAST(NULL AS STRING), TO_TIMESTAMP_LTZ(1700007000, 3)),
  ('case_009', CAST(NULL AS STRING),               1,              'carol',  'FAIL',              TO_TIMESTAMP_LTZ(1700008000, 3)),
  ('case_010', 'Session expiry not handled',       CAST(NULL AS INT), 'alice', 'PASS',            TO_TIMESTAMP_LTZ(1700009000, 3));