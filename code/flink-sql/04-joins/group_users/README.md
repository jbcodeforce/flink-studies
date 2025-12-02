# A Simple Join

## Problem
 Build a Dimension that define what user belonging to group?.  

## Context

* In the  groups_users_rec there is only events for group/users creation or update
* The event that specifies a user is deleted from a group will not come in this source. Only an event saying the group has a delete in the form
    ```sql
    ('grp-002', '', TIMESTAMP '2025-11-26 09:15:00.000', TRUE)
    ```

    Let call it a tombstone at the group level.

* If the delete events are sent for a given user within a group like:
    ```
    ('grp-002', 'user_201', TIMESTAMP '2025-11-26 09:15:00.000', TRUE)
    ```

    Then to address the requirement, the following statement will work:
    ```sql
    select group_uid, group_member,  is_deleted from `groups_users_rec` group by group_uid, group_member, is_deleted
    ```

*  Fetching data from datasource should be ordered. But it could be out of order in some rare case.
* When a group has been modified and the event is a tombstone, normally all users should be deleted so the `is_deteled` flag, should be set to True

* We need to handle a "tombstone" event where an empty group_member with is_deleted=TRUE marks all existing members of that group as deleted, unless they have newer events after the tombstone.
* On this example:
    ```sql
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
    ```

    The expected results is:
    ```
    'grp-001', 'user-100', FALSE
    'grp-001', 'user-101', FALSE
    'grp-001', 'user-102', FALSE
    'grp-002', 'user-200', FALSE
    'grp-002', 'user-201', TRUE
    'grp-002', 'user-202', FALSE
    'grp-003', 'user-300', FALSE
    'grp-003', 'user-301', FALSE
    ```

The final query is:
```sql
INSERT INTO dim_latest_group_users_rec
SELECT
    group_uid,
    group_member,
    event_timestamp,
    CASE
        WHEN tombstone_ts IS NOT NULL
             AND event_timestamp < tombstone_ts
        THEN TRUE
        ELSE is_deleted
    END as is_deleted
FROM (SELECT
        r.group_uid,
        r.group_member,
        r.event_timestamp,
        r.is_deleted,
        -- Get the maximum tombstone timestamp for each group
        t.tombstone_timestamp as tombstone_ts
    FROM groups_users_rec r
    LEFT JOIN (
        SELECT
            group_uid,
            MAX(event_timestamp) as tombstone_timestamp
        FROM groups_users_rec
        WHERE group_member = '' AND is_deleted = TRUE
        GROUP BY group_uid
    ) t ON r.group_uid = t.group_uid
    WHERE r.group_member <> '' );
```