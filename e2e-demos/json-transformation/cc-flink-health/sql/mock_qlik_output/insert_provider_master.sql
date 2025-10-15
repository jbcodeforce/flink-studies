-- Insert records into provider_master table
INSERT INTO provider_master
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
    CONCAT('{',
        '"providerId": "PRV', CAST(id AS STRING), '", ',
        '"npi": "', CAST(1000000000 + id AS STRING), '", ',
        '"firstName": "',
        CASE MOD(id, 10)
            WHEN 0 THEN 'William'
            WHEN 1 THEN 'Elizabeth'
            WHEN 2 THEN 'David'
            WHEN 3 THEN 'Sarah'
            WHEN 4 THEN 'Michael'
            WHEN 5 THEN 'Jennifer'
            WHEN 6 THEN 'Richard'
            WHEN 7 THEN 'Margaret'
            WHEN 8 THEN 'Thomas'
            ELSE 'Patricia'
        END, '", ',
        '"lastName": "',
        CASE MOD(id, 10)
            WHEN 0 THEN 'Anderson'
            WHEN 1 THEN 'Baker'
            WHEN 2 THEN 'Clark'
            WHEN 3 THEN 'Davis'
            WHEN 4 THEN 'Edwards'
            WHEN 5 THEN 'Fisher'
            WHEN 6 THEN 'Garcia'
            WHEN 7 THEN 'Harris'
            WHEN 8 THEN 'Jackson'
            ELSE 'Kennedy'
        END, '", ',
        '"specialty": "',
        CASE MOD(id, 8)
            WHEN 0 THEN 'Family Medicine'
            WHEN 1 THEN 'Internal Medicine'
            WHEN 2 THEN 'Pediatrics'
            WHEN 3 THEN 'Cardiology'
            WHEN 4 THEN 'Orthopedics'
            WHEN 5 THEN 'Dermatology'
            WHEN 6 THEN 'Neurology'
            ELSE 'Oncology'
        END, '", ',
        '"practiceName": "',
        CASE MOD(id, 6)
            WHEN 0 THEN 'Community Health Center'
            WHEN 1 THEN 'Medical Associates'
            WHEN 2 THEN 'Family Care Clinic'
            WHEN 3 THEN 'Specialty Care Center'
            WHEN 4 THEN 'Regional Medical Group'
            ELSE 'Healthcare Partners'
        END, '", ',
        '"address": "',
        CAST(100 + MOD(id, 900) AS STRING), ' ',
        CASE MOD(id, 5)
            WHEN 0 THEN 'Medical'
            WHEN 1 THEN 'Health'
            WHEN 2 THEN 'Park'
            WHEN 3 THEN 'Professional'
            ELSE 'Center'
        END, ' ',
        CASE MOD(id, 3)
            WHEN 0 THEN 'Drive'
            WHEN 1 THEN 'Plaza'
            ELSE 'Boulevard'
        END, '", ',
        '"status": "',
        CASE MOD(id, 4)
            WHEN 0 THEN 'Active'
            WHEN 1 THEN 'Active'
            WHEN 2 THEN 'Active'
            ELSE 'Inactive'
        END, '", ',
        '"licenseNumber": "', CAST(50000 + id AS STRING), '", ',
        '"lastUpdated": "', CAST(CURRENT_DATE AS STRING), '"',
    '}') AS data,
    
    -- BeforeData (null for INSERT operations)
    CASE 
        WHEN MOD(id, 3) = 0 THEN NULL  -- INSERT operations have no before data
        ELSE CONCAT('{',
            '"providerId": "PRV', CAST(id AS STRING), '", ',
            '"version": ', CAST(MOD(id, 5) AS STRING),
            '}')
    END AS beforeData,
    
    -- SystemOfRecord
    ROW(
        CASE MOD(id, 3)
            WHEN 0 THEN 'CREDENTIALING'
            WHEN 1 THEN 'PROVIDER_PORTAL'
            ELSE 'ADMIN_SYSTEM'
        END,
        'PROVIDER',
        CAST(CURRENT_DATE AS STRING),
        UUID(),
        CONCAT('PRV', CAST(id AS STRING))
    ) AS systemOfRecord

FROM lateral table(SEQUENCE(1, 30)) AS t(id);
