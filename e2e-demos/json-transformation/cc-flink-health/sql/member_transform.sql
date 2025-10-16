-- Member transformation
INSERT INTO member_dimension
SELECT
    -- Map primary fields from JSON data
    JSON_VALUE(data, '$.member_id') AS member_id,
    JSON_VALUE(data, '$.first_name') AS first_name,
    JSON_VALUE(data, '$.last_name') AS last_name,
    JSON_VALUE(data, '$.date_of_birth') AS date_of_birth,
    -- Create nested address structure from JSON fields
    ROW(
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.street'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.city'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.state'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.postal_code')
    ) AS address,
    JSON_VALUE(data, '$.phone') AS phone,
    JSON_VALUE(data, '$.email') AS email
FROM person_mdm
-- Filter out DELETE operations from CDC
WHERE headers.op <> 'DELETE';
