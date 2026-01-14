INSERT INTO staging_cdc_marqeta_jcard_tranlog_history
WITH ranked_by_transaction_all AS (
    SELECT
        JSON_VALUE(record_content, '$.prg_id') AS __jetstream__prg_id,
        JSON_VALUE(record_content, '$.shard_id') AS __jetstream__shard_id,
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.entry_createdate') AS BIGINT), 3) AS __jetstream__entry_createdate,
        JSON_VALUE(record_content, '$.op') = 'd' AS __jetstream__deleted,
        CURRENT_TIMESTAMP AS __jetstream__loaded_at,
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.source.ts_ms') AS BIGINT), 3) AS __jetstream__source_ts,
        JSON_VALUE(record_content, '$.transaction.id') AS __jetstream__transaction_id,
        JSON_VALUE(record_content, '$.source.gtid') AS __jetstream__gtid,
        JSON_VALUE(record_metadata, '$.offset') AS __jetstream__offset,
        JSON_VALUE(record_metadata, '$.partition') AS __jetstream__partition,
        JSON_VALUE(record_metadata, '$.key') AS __jetstream__key,
        TO_TIMESTAMP(CAST(JSON_VALUE(record_content, '$.ts_ms') AS BIGINT), 3) AS __jetstream__ts,
        JSON_VALUE(record_content, '$.transaction.total_order') AS __jetstream__total_order,
        JSON_VALUE(record_content, '$.transaction.data_collection_order') AS __jetstream__data_collection_order,
        JSON_VALUE(record_content, '$.source.name') AS __jetstream__source_name,
        JSON_VALUE(record_content, '$.source.db') AS __jetstream__source_db,
        JSON_VALUE(record_content, '$.source.table') AS __jetstream__source_table,
        CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) AS __jetstream__server_uuid,
        CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) AS __jetstream__server_transaction_id,
        JSON_VALUE(record_content, '$.op') AS __jetstream__op,
        COALESCE(CAST(JSON_VALUE(record_content, '$.source.snapshot') AS BOOLEAN), TRUE) AS __jetstream__snapshot,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_street') ELSE JSON_VALUE(record_content, '$.after.ca_street') END AS STRING) AS ca_street,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.response') ELSE JSON_VALUE(record_content, '$.after.response') END AS STRING) AS response,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.transactionState') ELSE JSON_VALUE(record_content, '$.after.transactionState') END AS STRING) AS transactionState,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.reversalCount') ELSE JSON_VALUE(record_content, '$.after.reversalCount') END AS DECIMAL(38, 0)) AS reversalCount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.retrievalReferenceNumber') ELSE JSON_VALUE(record_content, '$.after.retrievalReferenceNumber') END AS STRING) AS retrievalReferenceNumber,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.irc') ELSE JSON_VALUE(record_content, '$.after.irc') END AS STRING) AS irc,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.displayMessage') ELSE JSON_VALUE(record_content, '$.after.displayMessage') END AS STRING) AS displayMessage,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.glTransaction') ELSE JSON_VALUE(record_content, '$.after.glTransaction') END AS DECIMAL(38, 0)) AS glTransaction,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.refId') ELSE JSON_VALUE(record_content, '$.after.refId') END AS DECIMAL(38, 0)) AS refId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.networkReferenceId') ELSE JSON_VALUE(record_content, '$.after.networkReferenceId') END AS STRING) AS networkReferenceId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.voidCount') ELSE JSON_VALUE(record_content, '$.after.voidCount') END AS DECIMAL(38, 0)) AS voidCount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.issuerFee') ELSE JSON_VALUE(record_content, '$.after.issuerFee') END AS DECIMAL(38, 4)) AS issuerFee,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.voidId') ELSE JSON_VALUE(record_content, '$.after.voidId') END AS DECIMAL(38, 0)) AS voidId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.createdTime') ELSE JSON_VALUE(record_content, '$.after.createdTime') END AS TIMESTAMP(3)) AS createdTime,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.actingCardHolder') ELSE JSON_VALUE(record_content, '$.after.actingCardHolder') END AS DECIMAL(38, 0)) AS actingCardHolder,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.network') ELSE JSON_VALUE(record_content, '$.after.network') END AS STRING) AS network,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.amount') ELSE JSON_VALUE(record_content, '$.after.amount') END AS DECIMAL(38, 2)) AS amount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.tags') ELSE JSON_VALUE(record_content, '$.after.tags') END AS STRING) AS tags,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.gatewaylog') ELSE JSON_VALUE(record_content, '$.after.gatewaylog') END AS DECIMAL(38, 0)) AS gatewaylog,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.networkMid') ELSE JSON_VALUE(record_content, '$.after.networkMid') END AS STRING) AS networkMid,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.lastModifiedTime') ELSE JSON_VALUE(record_content, '$.after.lastModifiedTime') END AS TIMESTAMP(3)) AS lastModifiedTime,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.mid') ELSE JSON_VALUE(record_content, '$.after.mid') END AS STRING) AS mid,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_mallName') ELSE JSON_VALUE(record_content, '$.after.ca_mallName') END AS STRING) AS ca_mallName,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.id') ELSE JSON_VALUE(record_content, '$.after.id') END AS DECIMAL(38, 0)) AS id,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.multiClearCount') ELSE JSON_VALUE(record_content, '$.after.multiClearCount') END AS DECIMAL(38, 0)) AS multiClearCount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.committedUsed') ELSE JSON_VALUE(record_content, '$.after.committedUsed') END AS DECIMAL(38, 2)) AS committedUsed,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_city') ELSE JSON_VALUE(record_content, '$.after.ca_city') END AS STRING) AS ca_city,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.responseAmount') ELSE JSON_VALUE(record_content, '$.after.responseAmount') END AS DECIMAL(38, 2)) AS responseAmount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.requestAmount') ELSE JSON_VALUE(record_content, '$.after.requestAmount') END AS DECIMAL(38, 2)) AS requestAmount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.originalItc') ELSE JSON_VALUE(record_content, '$.after.originalItc') END AS STRING) AS originalItc,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.extrc') ELSE JSON_VALUE(record_content, '$.after.extrc') END AS STRING) AS extrc,
        TO_TIMESTAMP(CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.date') ELSE JSON_VALUE(record_content, '$.after.date') END AS BIGINT), 3) AS date,
        TO_TIMESTAMP(CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.transmissionDate') ELSE JSON_VALUE(record_content, '$.after.transmissionDate') END AS BIGINT), 3) AS transmissionDate,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.completionId') ELSE JSON_VALUE(record_content, '$.after.completionId') END AS DECIMAL(38, 0)) AS completionId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.stan') ELSE JSON_VALUE(record_content, '$.after.stan') END AS STRING) AS stan,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.acquirerReferenceId') ELSE JSON_VALUE(record_content, '$.after.acquirerReferenceId') END AS STRING) AS acquirerReferenceId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.responseCode') ELSE JSON_VALUE(record_content, '$.after.responseCode') END AS STRING) AS responseCode,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.completionCount') ELSE JSON_VALUE(record_content, '$.after.completionCount') END AS DECIMAL(38, 0)) AS completionCount,
        CAST(TO_TIMESTAMP(CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.captureDate') ELSE JSON_VALUE(record_content, '$.after.captureDate') END AS BIGINT), 3) AS DATE) AS captureDate,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.reversalId') ELSE JSON_VALUE(record_content, '$.after.reversalId') END AS DECIMAL(38, 0)) AS reversalId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.expirationTime') ELSE JSON_VALUE(record_content, '$.after.expirationTime') END AS TIMESTAMP(3)) AS expirationTime,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.fileName') ELSE JSON_VALUE(record_content, '$.after.fileName') END AS STRING) AS fileName,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_zip') ELSE JSON_VALUE(record_content, '$.after.ca_zip') END AS STRING) AS ca_zip,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.currencyCode') ELSE JSON_VALUE(record_content, '$.after.currencyCode') END AS STRING) AS currencyCode,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.tid') ELSE JSON_VALUE(record_content, '$.after.tid') END AS STRING) AS tid,
        CAST(TO_TIMESTAMP(CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.settlementDate') ELSE JSON_VALUE(record_content, '$.after.settlementDate') END AS BIGINT), 3) AS DATE) AS settlementDate,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_region') ELSE JSON_VALUE(record_content, '$.after.ca_region') END AS STRING) AS ca_region,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.acquirerFee') ELSE JSON_VALUE(record_content, '$.after.acquirerFee') END AS DECIMAL(38, 4)) AS acquirerFee,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.functionCode') ELSE JSON_VALUE(record_content, '$.after.functionCode') END AS STRING) AS functionCode,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_country') ELSE JSON_VALUE(record_content, '$.after.ca_country') END AS STRING) AS ca_country,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_name') ELSE JSON_VALUE(record_content, '$.after.ca_name') END AS STRING) AS ca_name,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.forwardingInstId') ELSE JSON_VALUE(record_content, '$.after.forwardingInstId') END AS STRING) AS forwardingInstId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.approvalNumber') ELSE JSON_VALUE(record_content, '$.after.approvalNumber') END AS STRING) AS approvalNumber,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.incomingNetworkRequestITC') ELSE JSON_VALUE(record_content, '$.after.incomingNetworkRequestITC') END AS STRING) AS incomingNetworkRequestITC,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.adviceId') ELSE JSON_VALUE(record_content, '$.after.adviceId') END AS DECIMAL(38, 0)) AS adviceId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.reasonCode') ELSE JSON_VALUE(record_content, '$.after.reasonCode') END AS STRING) AS reasonCode,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.card') ELSE JSON_VALUE(record_content, '$.after.card') END AS DECIMAL(38, 0)) AS card,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.digitalWalletToken') ELSE JSON_VALUE(record_content, '$.after.digitalWalletToken') END AS DECIMAL(38, 0)) AS digitalWalletToken,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.feeRate') ELSE JSON_VALUE(record_content, '$.after.feeRate') END AS DECIMAL(38, 3)) AS feeRate,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.additionalAmount') ELSE JSON_VALUE(record_content, '$.after.additionalAmount') END AS DECIMAL(38, 2)) AS additionalAmount,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.cardHolder') ELSE JSON_VALUE(record_content, '$.after.cardHolder') END AS DECIMAL(38, 0)) AS cardHolder,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.subNetwork') ELSE JSON_VALUE(record_content, '$.after.subNetwork') END AS STRING) AS subNetwork,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.batchNumber') ELSE JSON_VALUE(record_content, '$.after.batchNumber') END AS DECIMAL(38, 0)) AS batchNumber,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.originator') ELSE JSON_VALUE(record_content, '$.after.originator') END AS STRING) AS originator,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.acquirer') ELSE JSON_VALUE(record_content, '$.after.acquirer') END AS STRING) AS acquirer,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.itc') ELSE JSON_VALUE(record_content, '$.after.itc') END AS STRING) AS itc,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.outstanding') ELSE JSON_VALUE(record_content, '$.after.outstanding') END AS DECIMAL(38, 0)) AS outstanding,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.node') ELSE JSON_VALUE(record_content, '$.after.node') END AS STRING) AS node,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.duration') ELSE JSON_VALUE(record_content, '$.after.duration') END AS DECIMAL(38, 0)) AS duration,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.account') ELSE JSON_VALUE(record_content, '$.after.account') END AS DECIMAL(38, 0)) AS account,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.request') ELSE JSON_VALUE(record_content, '$.after.request') END AS STRING) AS request,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.rc') ELSE JSON_VALUE(record_content, '$.after.rc') END AS STRING) AS rc,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.mcc') ELSE JSON_VALUE(record_content, '$.after.mcc') END AS STRING) AS mcc,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.localId') ELSE JSON_VALUE(record_content, '$.after.localId') END AS DECIMAL(38, 0)) AS localId,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.returnedBalances') ELSE JSON_VALUE(record_content, '$.after.returnedBalances') END AS STRING) AS returnedBalances,
        TO_TIMESTAMP(CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.localTransactionDate') ELSE JSON_VALUE(record_content, '$.after.localTransactionDate') END AS BIGINT), 3) AS localTransactionDate,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.remoteHost') ELSE JSON_VALUE(record_content, '$.after.remoteHost') END AS STRING) AS remoteHost,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.ca_storeNumber') ELSE JSON_VALUE(record_content, '$.after.ca_storeNumber') END AS STRING) AS ca_storeNumber,
        CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.account2') ELSE JSON_VALUE(record_content, '$.after.account2') END AS DECIMAL(38, 0)) AS account2,
        ROW_NUMBER() OVER (
            PARTITION BY JSON_VALUE(record_content, '$.prg_id'),
                JSON_VALUE(record_content, '$.shard_id'),
                CAST(CASE WHEN JSON_VALUE(record_content, '$.op') = 'd' THEN JSON_VALUE(record_content, '$.before.id') ELSE JSON_VALUE(record_content, '$.after.id') END AS DECIMAL(38, 0)),
                CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING)
            ORDER BY
                CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) DESC,
                CAST(JSON_VALUE(record_content, '$.source.pos') AS INTEGER) DESC,
                CAST(JSON_VALUE(record_content, '$.transaction.data_collection_order') AS INTEGER) DESC
        ) AS transaction_rank
    FROM cdc_marqeta_jcard_tranlog_history h
    WHERE CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) != 'NA'
        AND ((CAST(JSON_VALUE(record_content, '$.server_uuid') AS STRING) = server_uuid('server_uuid_1:1000')
            AND CAST(JSON_VALUE(record_content, '$.server_transaction_id') AS INTEGER) BETWEEN COALESCE(transaction_id('server_uuid_1:1034'), 0) AND transaction_id('server_uuid_1:1000')))
),
ranked_by_ts_all AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY __jetstream__prg_id,
                __jetstream__shard_id,
                id
            ORDER BY
                __jetstream__source_ts DESC
        ) AS ts_rank
    FROM
        ranked_by_transaction_all
    WHERE
        transaction_rank = 1
)
SELECT
    *
FROM
    ranked_by_ts_all
WHERE
    ts_rank = 1
