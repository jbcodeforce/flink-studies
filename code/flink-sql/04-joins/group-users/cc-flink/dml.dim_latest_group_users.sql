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