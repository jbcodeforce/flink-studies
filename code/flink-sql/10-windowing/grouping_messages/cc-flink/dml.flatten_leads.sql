INSERT INTO leads_raw
SELECT
    lead_id AS `key`,
    CONCAT(
        '{"id":"', REPLACE(lead_id, '"', '\\"'), '"',
        ',"tenant_id":"', REPLACE(tenant_id, '"', '\\"'), '"',
        ',"name":"', REPLACE(name, '"', '\\"'), '"',
        ',"__op":"', __op, '"', '"}'
    ) AS `val`

FROM `j9r-env.j9r-kafka.leads_faker`;