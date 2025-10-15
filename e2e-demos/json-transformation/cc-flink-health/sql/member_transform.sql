-- Member transformation
INSERT INTO member_sink
SELECT
    -- Map primary fields from JSON data
    JSON_VALUE(data, '$.AUTH_ID') AS member_id,
    JSON_VALUE(data, '$.first_name') AS first_name,
    JSON_VALUE(data, '$.last_name') AS last_name,
    JSON_VALUE(data, '$.birth_date') AS date_of_birth,
    -- Create nested address structure from JSON fields
    ROW(
        JSON_VALUE(data, '$.street_address'),
        JSON_VALUE(data, '$.city'),
        JSON_VALUE(data, '$.state'),
        JSON_VALUE(data, '$.postal_code')
    ) AS address,
    JSON_VALUE(data, '$.phone_number') AS phone,
    JSON_VALUE(data, '$.email_address') AS email
FROM person_mdm
-- Filter out DELETE operations from CDC
WHERE op != 'DELETE';
