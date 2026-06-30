-- Parse generic envelope, resolve party_id, expand to all party accounts,
-- self-join event_stream for sibling subscription rows.
INSERT INTO enriched_party_events
SELECT /*+ STATE_TTL('es'='6d', 'sub'='6d', 'pi'='0', 'pi2'='0') */
    es.event_id,
    COALESCE(pi2.account_number, es.account_number) AS related_account_id,
    es.event_time,
    es.event_type,
    es.account_number,
    pi.party_id,
    sub.plan_name,
    sub.subscription_start
FROM (
    SELECT
        e.event_id,
        e.event_time,
        JSON_VALUE(e.context_data, 'lax $.eventType') AS event_type,
        JSON_VALUE(t.detail, 'lax $.account_number') AS account_number
    FROM event_stream e
    CROSS JOIN UNNEST(e.event_details) AS t(detail)
    WHERE JSON_VALUE(t.detail, 'lax $.account_number') IS NOT NULL
) es
LEFT JOIN party_info pi
    ON es.account_number = pi.account_number
LEFT JOIN party_info pi2
    ON pi.party_id = pi2.party_id
LEFT JOIN (
    SELECT
        JSON_VALUE(d.detail, 'lax $.account_number') AS account_number,
        JSON_VALUE(d.detail, 'lax $.plan_name') AS plan_name,
        CAST(JSON_VALUE(d.detail, 'lax $.subscription_start') AS TIMESTAMP_LTZ(3)) AS subscription_start
    FROM event_stream e
    CROSS JOIN UNNEST(e.event_details) AS d(detail)
    WHERE JSON_VALUE(e.context_data, 'lax $.eventType') = 'subscription'
) sub
    ON pi2.account_number = sub.account_number;
