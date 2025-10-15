INSERT INTO person_mdm
SELECT
    -- Headers
    ROW(
        CASE MOD(id, 3)
            WHEN 0 THEN 'INSERT'
            WHEN 1 THEN 'UPDATE'
            ELSE 'DELETE'
        END,
        UNIX_TIMESTAMP() * 1000 + id,  -- Unique timestamp for each record
        CAST(UUID() AS STRING)         -- Unique transaction ID
    ) AS headers,
    
    -- Data (JSON string)
    CASE MOD(id, 10)
        -- 10% duplicate records (every 10th record is a duplicate of record 1)
        WHEN 0 THEN '{"personId": "P001", "firstName": "John", "lastName": "Doe", "dateOfBirth": "1980-01-01", "gender": "M", "address": "123 Main St"}'
        ELSE CONCAT('{"personId": "P', CAST(id AS STRING), 
            '", "firstName": "', 
            CASE MOD(id, 5)
                WHEN 0 THEN 'James'
                WHEN 1 THEN 'Mary'
                WHEN 2 THEN 'Robert'
                WHEN 3 THEN 'Patricia'
                ELSE 'Michael'
            END,
            '", "lastName": "',
            CASE MOD(id, 5)
                WHEN 0 THEN 'Smith'
                WHEN 1 THEN 'Johnson'
                WHEN 2 THEN 'Williams'
                WHEN 3 THEN 'Brown'
                ELSE 'Jones'
            END,
            '", "dateOfBirth": "',
            CAST(CURRENT_DATE as STRING), 
            '", "gender": "',
            CASE MOD(id, 2) WHEN 0 THEN 'M' ELSE 'F' END,
            '", "address": "',
            CAST(100 + MOD(id, 900) AS STRING),
            ' ',
            CASE MOD(id, 4)
                WHEN 0 THEN 'Main'
                WHEN 1 THEN 'Oak'
                WHEN 2 THEN 'Maple'
                ELSE 'Cedar'
            END,
            ' ',
            CASE MOD(id, 3)
                WHEN 0 THEN 'Street'
                WHEN 1 THEN 'Avenue'
                ELSE 'Road'
            END,
            '"}'
        )
    END AS data,
    
    -- BeforeData (null for INSERT operations)
    CASE 
        WHEN MOD(id, 3) = 0 THEN NULL  -- INSERT operations have no before data
        ELSE '{"personId": "P' || LPAD(CAST(id AS STRING), 3, '0') || '", "version": ' || CAST(MOD(id, 5) AS STRING) || '}'
    END AS beforeData,
    
    -- SystemOfRecord
    ROW(
        CASE MOD(id, 3)
            WHEN 0 THEN 'CRM'
            WHEN 1 THEN 'EHR'
            ELSE 'CLAIMS'
        END,
        'PERSON',
        DATE_FORMAT(CURRENT_TIMESTAMP, 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'),
        UUID(),
        'P' || LPAD(CAST(id AS STRING), 3, '0')
    ) AS systemOfRecord

FROM lateral table(SEQUENCE(1, 30)) AS t(id)
