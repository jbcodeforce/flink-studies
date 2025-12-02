INSERT INTO groups_users_rec (group_uid, group_member, event_timestamp, is_deleted) VALUES
  ('grp-001', 'user-100', TIMESTAMP '2025-11-01 09:00:00.000', FALSE),
  ('grp-001', 'user-101', TIMESTAMP '2025-11-01 09:05:00.500', FALSE),
  ('grp-002', 'user-200', TIMESTAMP '2025-11-02 10:10:10.123', FALSE),
  ('grp-002', 'user-201', TIMESTAMP '2025-11-02 10:12:00.000', FALSE),
  ('grp-003', 'user-300', TIMESTAMP '2025-11-15 14:30:22.999', FALSE),
  -- deletion in grp-002
  ('grp-002', '', TIMESTAMP '2025-11-26 09:15:00.000', TRUE),
  ('grp-003', 'user-301', TIMESTAMP '2025-11-28 20:45:15.250', FALSE),
  ('grp-001', 'user-102', TIMESTAMP '2025-11-30 23:59:59.999', FALSE),
  ('grp-002', 'user-200', TIMESTAMP '2025-11-26 10:11:10.123', FALSE),
  ('grp-002', 'user-202', TIMESTAMP '2025-11-26 10:12:00.000', FALSE);