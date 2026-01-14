INSERT INTO transaction_tracking
WITH all_transactions AS (
    SELECT
        CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) AS server_uuid,
        CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) AS transaction_id,
        CAST(JSON_VALUE(record_content, '$.entry_createdate') AS TIMESTAMP(3)) AS entry_createdate,
        0 AS dml_event_count
    FROM cdc_marqeta_jcard_uberddl
    WHERE
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.ts_ms') AS BIGINT), 3) >= TIMESTAMPADD(DAY, -3, CURRENT_TIMESTAMP)
        AND CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) != 'NA'
        AND ((CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_2:1001')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_2:1022'), 0) AND transaction_id('server_uuid_2:1001'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_3:1002')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_3:1002'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_4:1003')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_4:1023'), 0) AND transaction_id('server_uuid_4:1003'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_5:1004')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_5:1024'), 0) AND transaction_id('server_uuid_5:1004'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_6:1005')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_6:1005'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_7:1006')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_7:1025'), 0) AND transaction_id('server_uuid_7:1006'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_8:1007')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_8:1007'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_9:1008')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_9:1026'), 0) AND transaction_id('server_uuid_9:1008'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_10:1009')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_10:1027'), 0) AND transaction_id('server_uuid_10:1009'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_11:1010')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_11:1010'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_12:1011')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_12:1028'), 0) AND transaction_id('server_uuid_12:1011'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_13:1012')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_13:1029'), 0) AND transaction_id('server_uuid_13:1012'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_14:1013')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_14:1030'), 0) AND transaction_id('server_uuid_14:1013'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_15:1014')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_15:1014'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_16:1015')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_16:1015'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_17:1016')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_17:1031'), 0) AND transaction_id('server_uuid_17:1016'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_18:1017')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_18:1017'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_19:1018')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_19:1032'), 0) AND transaction_id('server_uuid_19:1018'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_20:1019')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_20:1033'), 0) AND transaction_id('server_uuid_20:1019'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_21:1020')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_21:1020'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_1:1021')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_1:1034'), 0) AND transaction_id('server_uuid_1:1021')))
    UNION ALL
    SELECT
        CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) AS server_uuid,
        CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) AS transaction_id,
        CAST(JSON_VALUE(record_content, '$.entry_createdate') AS TIMESTAMP(3)) AS entry_createdate,
        0 AS dml_event_count
    FROM cdc_marqeta_jcard_ddl
    WHERE
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.ts_ms') AS BIGINT), 3) >= TIMESTAMPADD(DAY, -3, CURRENT_TIMESTAMP)
        AND CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) != 'NA'
        AND ((CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_2:1001')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_2:1022'), 0) AND transaction_id('server_uuid_2:1001'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_3:1002')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_3:1002'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_4:1003')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_4:1023'), 0) AND transaction_id('server_uuid_4:1003'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_5:1004')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_5:1024'), 0) AND transaction_id('server_uuid_5:1004'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_6:1005')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_6:1005'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_7:1006')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_7:1025'), 0) AND transaction_id('server_uuid_7:1006'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_8:1007')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_8:1007'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_9:1008')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_9:1026'), 0) AND transaction_id('server_uuid_9:1008'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_10:1009')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_10:1027'), 0) AND transaction_id('server_uuid_10:1009'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_11:1010')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_11:1010'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_12:1011')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_12:1028'), 0) AND transaction_id('server_uuid_12:1011'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_13:1012')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_13:1029'), 0) AND transaction_id('server_uuid_13:1012'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_14:1013')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_14:1030'), 0) AND transaction_id('server_uuid_14:1013'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_15:1014')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_15:1014'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_16:1015')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_16:1015'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_17:1016')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_17:1031'), 0) AND transaction_id('server_uuid_17:1016'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_18:1017')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_18:1017'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_19:1018')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_19:1032'), 0) AND transaction_id('server_uuid_19:1018'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_20:1019')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_20:1033'), 0) AND transaction_id('server_uuid_20:1019'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_21:1020')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_21:1020'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_1:1021')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_1:1034'), 0) AND transaction_id('server_uuid_1:1021')))
    UNION ALL
    SELECT
        CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) AS server_uuid,
        CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) AS transaction_id,
        CAST(JSON_VALUE(record_content, '$.entry_createdate') AS TIMESTAMP(3)) AS entry_createdate,
        COALESCE(CAST(JSON_VALUE(e.value, '$.event_count') AS INTEGER), 0) AS dml_event_count
    FROM cdc_marqeta_jcard_dbtransaction h
    CROSS JOIN UNNEST(
        ARRAY_CONCAT(
            CAST(JSON_EXTRACT(record_content, '$.data_collections') AS ARRAY<STRING>),
            ARRAY['{"data_collection": "dummy.tranlog", "event_count": 0}']
        )
    ) AS e(value)
    WHERE
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.ts_ms') AS BIGINT), 3) >= TIMESTAMPADD(DAY, -3, CURRENT_TIMESTAMP)
        AND CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) != 'NA'
        AND REGEXP_EXTRACT(JSON_VALUE(e.value, '$.data_collection'), '\\.([^.]+)$', 1) = 'tranlog'
        AND JSON_VALUE(record_content, '$.status') = 'END'
        AND ((CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_2:1001')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_2:1022'), 0) AND transaction_id('server_uuid_2:1001'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_3:1002')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_3:1002'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_4:1003')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_4:1023'), 0) AND transaction_id('server_uuid_4:1003'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_5:1004')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_5:1024'), 0) AND transaction_id('server_uuid_5:1004'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_6:1005')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_6:1005'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_7:1006')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_7:1025'), 0) AND transaction_id('server_uuid_7:1006'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_8:1007')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_8:1007'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_9:1008')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_9:1026'), 0) AND transaction_id('server_uuid_9:1008'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_10:1009')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_10:1027'), 0) AND transaction_id('server_uuid_10:1009'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_11:1010')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_11:1010'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_12:1011')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_12:1028'), 0) AND transaction_id('server_uuid_12:1011'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_13:1012')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_13:1029'), 0) AND transaction_id('server_uuid_13:1012'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_14:1013')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_14:1030'), 0) AND transaction_id('server_uuid_14:1013'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_15:1014')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_15:1014'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_16:1015')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_16:1015'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_17:1016')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_17:1031'), 0) AND transaction_id('server_uuid_17:1016'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_18:1017')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_18:1017'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_19:1018')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_19:1032'), 0) AND transaction_id('server_uuid_19:1018'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_20:1019')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_20:1033'), 0) AND transaction_id('server_uuid_20:1019'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_21:1020')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_21:1020'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_1:1021')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_1:1034'), 0) AND transaction_id('server_uuid_1:1021')))
),
transactions_counts AS (
    SELECT
        server_uuid,
        transaction_id,
        MAX(dml_event_count) AS dml_event_count,
        MAX(entry_createdate) AS entry_createdate
    FROM all_transactions
    GROUP BY
        server_uuid,
        transaction_id
),
events_counts AS (
    SELECT
        CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) AS server_uuid,
        CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) AS transaction_id,
        COUNT(DISTINCT
            CAST(JSON_VALUE(record_content, '$.source.pos') AS INTEGER),
            CAST(JSON_VALUE(record_content, '$.transaction.data_collection_order') AS INTEGER)
        ) AS dml_event_count
    FROM cdc_marqeta_jcard_tranlog_history
    WHERE
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.ts_ms') AS BIGINT), 3) >= TIMESTAMPADD(DAY, -3, CURRENT_TIMESTAMP)
        AND CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) != 'NA'
        AND ((CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_2:1001')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_2:1022'), 0) AND transaction_id('server_uuid_2:1001'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_3:1002')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_3:1002'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_4:1003')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_4:1023'), 0) AND transaction_id('server_uuid_4:1003'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_5:1004')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_5:1024'), 0) AND transaction_id('server_uuid_5:1004'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_6:1005')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_6:1005'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_7:1006')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_7:1025'), 0) AND transaction_id('server_uuid_7:1006'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_8:1007')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_8:1007'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_9:1008')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_9:1026'), 0) AND transaction_id('server_uuid_9:1008'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_10:1009')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_10:1027'), 0) AND transaction_id('server_uuid_10:1009'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_11:1010')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_11:1010'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_12:1011')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_12:1028'), 0) AND transaction_id('server_uuid_12:1011'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_13:1012')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_13:1029'), 0) AND transaction_id('server_uuid_13:1012'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_14:1013')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_14:1030'), 0) AND transaction_id('server_uuid_14:1013'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_15:1014')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_15:1014'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_16:1015')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_16:1015'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_17:1016')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_17:1031'), 0) AND transaction_id('server_uuid_17:1016'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_18:1017')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_18:1017'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_19:1018')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_19:1032'), 0) AND transaction_id('server_uuid_19:1018'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_20:1019')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_20:1033'), 0) AND transaction_id('server_uuid_20:1019'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_21:1020')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id(''), 0) AND transaction_id('server_uuid_21:1020'))
        OR (CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_1:1021')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_1:1034'), 0) AND transaction_id('server_uuid_1:1021')))
    GROUP BY
        server_uuid,
        transaction_id
),
groups AS (
    SELECT
        t.server_uuid,
        t.transaction_id,
        entry_createdate <= TIMESTAMPADD(HOUR, -2, CURRENT_TIMESTAMP) AS old_enough,
        CASE WHEN NOT entry_createdate <= TIMESTAMPADD(HOUR, -2, CURRENT_TIMESTAMP)
            THEN MIN(t.transaction_id) OVER (PARTITION BY t.server_uuid, entry_createdate <= TIMESTAMPADD(HOUR, -2, CURRENT_TIMESTAMP))
        END AS new_start,
        SUM(
            CASE WHEN t.dml_event_count <= COALESCE(e.dml_event_count, 0)
                THEN 0
                ELSE t.dml_event_count - COALESCE(e.dml_event_count, 0)
            END
        ) OVER (PARTITION BY t.server_uuid ORDER BY t.transaction_id) AS cumulative_missing_events,
        CASE WHEN t.dml_event_count < COALESCE(e.dml_event_count, 0)
            THEN 1
            ELSE 0
        END AS overcomplete,
        CASE t.server_uuid
            WHEN server_uuid('server_uuid_2:1022') THEN transaction_id('server_uuid_2:1022')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_4:1023') THEN transaction_id('server_uuid_4:1023')
            WHEN server_uuid('server_uuid_5:1024') THEN transaction_id('server_uuid_5:1024')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_7:1025') THEN transaction_id('server_uuid_7:1025')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_9:1026') THEN transaction_id('server_uuid_9:1026')
            WHEN server_uuid('server_uuid_10:1027') THEN transaction_id('server_uuid_10:1027')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_12:1028') THEN transaction_id('server_uuid_12:1028')
            WHEN server_uuid('server_uuid_13:1029') THEN transaction_id('server_uuid_13:1029')
            WHEN server_uuid('server_uuid_14:1030') THEN transaction_id('server_uuid_14:1030')
            WHEN '' THEN NULL
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_17:1031') THEN transaction_id('server_uuid_17:1031')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_19:1032') THEN transaction_id('server_uuid_19:1032')
            WHEN server_uuid('server_uuid_20:1033') THEN transaction_id('server_uuid_20:1033')
            WHEN '' THEN NULL
            WHEN server_uuid('server_uuid_1:1034') THEN transaction_id('server_uuid_1:1034')
        END AS transaction_id_offset,
        DENSE_RANK() OVER (
            PARTITION BY t.server_uuid,
                entry_createdate <= TIMESTAMPADD(HOUR, -2, CURRENT_TIMESTAMP)
            ORDER BY t.transaction_id
        ) - 1 AS relative_transaction_order
    FROM transactions_counts t
    LEFT JOIN events_counts e
        ON t.server_uuid = e.server_uuid
        AND t.transaction_id = e.transaction_id
),
intervals AS (
    SELECT
        server_uuid,
        MIN(transaction_id) AS begin,
        MAX(transaction_id) AS end,
        cumulative_missing_events = 0 AS complete,
        SUM(overcomplete) AS overcomplete_transactions,
        transaction_id - relative_transaction_order = new_start AS contiguous,
        CASE WHEN old_enough
            THEN transaction_id - relative_transaction_order - transaction_id_offset
        END AS cumulative_old_missing_transactions,
        old_enough,
        (cumulative_missing_events = 0) AND ((transaction_id - relative_transaction_order = new_start) OR old_enough) AS loadable
    FROM groups
    GROUP BY
        cumulative_missing_events = 0,
        cumulative_old_missing_transactions,
        transaction_id - relative_transaction_order = new_start,
        server_uuid,
        transaction_id_offset,
        old_enough,
        transaction_id,
        relative_transaction_order,
        new_start
)
SELECT
    server_uuid,
    MIN(CASE WHEN loadable THEN begin END) AS loadable_begin,
    MAX(CASE WHEN loadable THEN end END) AS loadable_end,
    MIN(CASE WHEN complete THEN begin END) AS complete_begin,
    MAX(CASE WHEN complete THEN end END) AS complete_end,
    MIN(CASE WHEN NOT complete THEN begin END) AS incomplete_begin,
    MAX(CASE WHEN NOT complete THEN end END) AS incomplete_end,
    MIN(CASE WHEN contiguous THEN begin END) AS contiguous_begin,
    MAX(CASE WHEN contiguous THEN end END) AS contiguous_end,
    MIN(CASE WHEN NOT contiguous THEN begin END) AS noncontiguous_begin,
    MAX(CASE WHEN NOT contiguous THEN end END) AS noncontiguous_end,
    MIN(CASE WHEN old_enough THEN begin END) AS old_enough_begin,
    MAX(CASE WHEN old_enough THEN end END) AS old_enough_end,
    COALESCE(MAX(cumulative_old_missing_transactions), 0) AS missing_old_transactions,
    SUM(overcomplete_transactions) AS overcomplete_transactions
FROM intervals
GROUP BY server_uuid
