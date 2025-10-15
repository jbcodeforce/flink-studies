-- Insert records into provider_master table

INSERT INTO provider_master(headers, afterData, beforeData, systemOfRecord, changeSet)
VALUES (
  -- Headers: operation type, timestamp, and a transaction ID
  (
    'INSERT',  -- operation type
     TO_TIMESTAMP('2025-10-15 08:30:00'),
    'TXN-2025101508300001'  -- transaction ID
  ),
  -- Data: JSON string containing provider information
  '{
    "providerId": "PRV123456",
    "npi": "1234567890",
    "firstName": "Sarah",
    "lastName": "Johnson",
    "specialty": "Family Medicine",
    "practiceName": "Johnson Family Care",
    "address": {
      "street": "123 Medical Center Drive",
      "city": "Portland",
      "state": "OR",
      "zipCode": "97201"
    },
    "contactInfo": {
      "phone": "503-555-0123",
      "email": "sjohnson@johnsoncare.example.com"
    },
    "active": true,
    "lastUpdated": "2025-10-15T08:30:00Z"
  }',
  CAST(NULL AS STRING),
  -- System of Record: metadata about the record
  (
    'QLIK_PROVIDER_SYSTEM',           -- sourceSystem
    'PROVIDER_MASTER',                -- sourceEntity
    '2025-10-15T08:30:00Z',          -- sourcePublishedDate
    'QLIK-PRV-2025101508300001',     -- sourceCorrelationReference
    'PRV123456'                       -- entityKey (matches providerId)
  ),
    ARRAY[('NetworkSet',    -- name
          ARRAY[('A2', ROW('1234'), 'srcPubRef01')]  -- changes
         )
       ]
),


(
  -- Headers: operation type, timestamp, and a transaction ID
  (
    'DELETE',  -- operation type
     TO_TIMESTAMP('2025-10-15 08:30:00'),
    'TXN-2025101508300002'  -- transaction ID
  ),
  -- Data: JSON string containing provider information
  '{
    "providerId": "PRV19999",
    "npi": "1234567890",
    "firstName": "Bob",
    "lastName": "Builder",
    "specialty": "Family Medicine",
    "practiceName": "Johnson Family Care",
    "address": {
      "street": "123 Medical Center Drive",
      "city": "Portland",
      "state": "OR",
      "zipCode": "97201"
    },
    "contactInfo": {
      "phone": "503-555-0123",
      "email": "bobbuilder@johnsoncare.example.com"
    },
    "active": true,
    "lastUpdated": "2025-10-15T08:30:00Z"
  }',
  CAST(NULL AS STRING),
  -- System of Record: metadata about the record
  (
    'QLIK_PROVIDER_SYSTEM',           -- sourceSystem
    'PROVIDER_MASTER',                -- sourceEntity
    '2025-10-15T08:30:00Z',          -- sourcePublishedDate
    'QLIK-PRV-2025101508300',     -- sourceCorrelationReference
    'PRV19999'                       -- entityKey (matches providerId)
  ),
    ARRAY[('NetworkSet',    -- name
          ARRAY[('A1', ROW('1234'), 'srcPubRef01')]  -- changes
         ) 
       ]
),

VALUES (
  -- Headers: operation type, timestamp, and a transaction ID
  (
    'INSERT',  -- operation type
     TO_TIMESTAMP('2025-10-15 08:30:00'),
    'TXN-2025101508300001'  -- transaction ID
  ),
  -- Data: JSON string containing provider information
  '{
    "providerId": "PRV123456",
    "npi": "1234567890",
    "firstName": "Sarah",
    "lastName": "Johnson",
    "specialty": "Family Medicine",
    "practiceName": "Johnson Family Care",
    "address": {
      "street": "123 Medical Center Drive",
      "city": "Portland",
      "state": "OR",
      "zipCode": "97201"
    },
    "contactInfo": {
      "phone": "503-555-0123",
      "email": "sjohnson@johnsoncare.example.com"
    },
    "active": true,
    "lastUpdated": "2025-10-15T08:30:00Z"
  }',
  CAST(NULL AS STRING),
  -- System of Record: metadata about the record
  (
    'QLIK_PROVIDER_SYSTEM',           -- sourceSystem
    'PROVIDER_MASTER',                -- sourceEntity
    '2025-10-15T08:30:00Z',          -- sourcePublishedDate
    'QLIK-PRV-2025101508300001',     -- sourceCorrelationReference
    'PRV123456'                       -- entityKey (matches providerId)
  ),
    ARRAY[('NetworkSet',    -- name
          ARRAY[('A2', ROW('1234'), 'srcPubRef01')]  -- changes
         )
       ]
)
;