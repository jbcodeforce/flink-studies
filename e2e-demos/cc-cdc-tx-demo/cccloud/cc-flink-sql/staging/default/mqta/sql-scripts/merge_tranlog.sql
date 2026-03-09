INSERT INTO tranlog
SELECT
    s.__jetstream__prg_id,
    s.__jetstream__shard_id,
    s.__jetstream__entry_createdate,
    s.__jetstream__deleted,
    s.__jetstream__loaded_at,
    s.__jetstream__source_ts,
    s.__jetstream__transaction_id,
    s.__jetstream__gtid,
    s.__jetstream__offset,
    s.__jetstream__partition,
    s.__jetstream__key,
    s.__jetstream__ts,
    s.__jetstream__total_order,
    s.__jetstream__data_collection_order,
    s.__jetstream__source_name,
    s.__jetstream__source_db,
    s.__jetstream__source_table,
    s.__jetstream__server_uuid,
    s.__jetstream__server_transaction_id,
    s.__jetstream__op,
    s.__jetstream__snapshot,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_street ELSE m.ca_street END AS ca_street,
    CASE WHEN NOT s.__jetstream__deleted THEN s.response ELSE m.response END AS response,
    CASE WHEN NOT s.__jetstream__deleted THEN s.transactionState ELSE m.transactionState END AS transactionState,
    CASE WHEN NOT s.__jetstream__deleted THEN s.reversalCount ELSE m.reversalCount END AS reversalCount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.retrievalReferenceNumber ELSE m.retrievalReferenceNumber END AS retrievalReferenceNumber,
    CASE WHEN NOT s.__jetstream__deleted THEN s.irc ELSE m.irc END AS irc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.displayMessage ELSE m.displayMessage END AS displayMessage,
    CASE WHEN NOT s.__jetstream__deleted THEN s.glTransaction ELSE m.glTransaction END AS glTransaction,
    CASE WHEN NOT s.__jetstream__deleted THEN s.refId ELSE m.refId END AS refId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.networkReferenceId ELSE m.networkReferenceId END AS networkReferenceId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.voidCount ELSE m.voidCount END AS voidCount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.issuerFee ELSE m.issuerFee END AS issuerFee,
    CASE WHEN NOT s.__jetstream__deleted THEN s.voidId ELSE m.voidId END AS voidId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.createdTime ELSE m.createdTime END AS createdTime,
    CASE WHEN NOT s.__jetstream__deleted THEN s.actingCardHolder ELSE m.actingCardHolder END AS actingCardHolder,
    CASE WHEN NOT s.__jetstream__deleted THEN s.network ELSE m.network END AS network,
    CASE WHEN NOT s.__jetstream__deleted THEN s.amount ELSE m.amount END AS amount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.tags ELSE m.tags END AS tags,
    CASE WHEN NOT s.__jetstream__deleted THEN s.gatewaylog ELSE m.gatewaylog END AS gatewaylog,
    CASE WHEN NOT s.__jetstream__deleted THEN s.networkMid ELSE m.networkMid END AS networkMid,
    CASE WHEN NOT s.__jetstream__deleted THEN s.lastModifiedTime ELSE m.lastModifiedTime END AS lastModifiedTime,
    CASE WHEN NOT s.__jetstream__deleted THEN s.mid ELSE m.mid END AS mid,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_mallName ELSE m.ca_mallName END AS ca_mallName,
    CASE WHEN NOT s.__jetstream__deleted THEN s.id ELSE m.id END AS id,
    CASE WHEN NOT s.__jetstream__deleted THEN s.multiClearCount ELSE m.multiClearCount END AS multiClearCount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.committedUsed ELSE m.committedUsed END AS committedUsed,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_city ELSE m.ca_city END AS ca_city,
    CASE WHEN NOT s.__jetstream__deleted THEN s.responseAmount ELSE m.responseAmount END AS responseAmount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.requestAmount ELSE m.requestAmount END AS requestAmount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.originalItc ELSE m.originalItc END AS originalItc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.extrc ELSE m.extrc END AS extrc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.date ELSE m.date END AS date,
    CASE WHEN NOT s.__jetstream__deleted THEN s.transmissionDate ELSE m.transmissionDate END AS transmissionDate,
    CASE WHEN NOT s.__jetstream__deleted THEN s.completionId ELSE m.completionId END AS completionId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.stan ELSE m.stan END AS stan,
    CASE WHEN NOT s.__jetstream__deleted THEN s.acquirerReferenceId ELSE m.acquirerReferenceId END AS acquirerReferenceId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.responseCode ELSE m.responseCode END AS responseCode,
    CASE WHEN NOT s.__jetstream__deleted THEN s.completionCount ELSE m.completionCount END AS completionCount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.captureDate ELSE m.captureDate END AS captureDate,
    CASE WHEN NOT s.__jetstream__deleted THEN s.reversalId ELSE m.reversalId END AS reversalId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.expirationTime ELSE m.expirationTime END AS expirationTime,
    CASE WHEN NOT s.__jetstream__deleted THEN s.fileName ELSE m.fileName END AS fileName,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_zip ELSE m.ca_zip END AS ca_zip,
    CASE WHEN NOT s.__jetstream__deleted THEN s.currencyCode ELSE m.currencyCode END AS currencyCode,
    CASE WHEN NOT s.__jetstream__deleted THEN s.tid ELSE m.tid END AS tid,
    CASE WHEN NOT s.__jetstream__deleted THEN s.settlementDate ELSE m.settlementDate END AS settlementDate,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_region ELSE m.ca_region END AS ca_region,
    CASE WHEN NOT s.__jetstream__deleted THEN s.acquirerFee ELSE m.acquirerFee END AS acquirerFee,
    CASE WHEN NOT s.__jetstream__deleted THEN s.functionCode ELSE m.functionCode END AS functionCode,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_country ELSE m.ca_country END AS ca_country,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_name ELSE m.ca_name END AS ca_name,
    CASE WHEN NOT s.__jetstream__deleted THEN s.forwardingInstId ELSE m.forwardingInstId END AS forwardingInstId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.approvalNumber ELSE m.approvalNumber END AS approvalNumber,
    CASE WHEN NOT s.__jetstream__deleted THEN s.incomingNetworkRequestITC ELSE m.incomingNetworkRequestITC END AS incomingNetworkRequestITC,
    CASE WHEN NOT s.__jetstream__deleted THEN s.adviceId ELSE m.adviceId END AS adviceId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.reasonCode ELSE m.reasonCode END AS reasonCode,
    CASE WHEN NOT s.__jetstream__deleted THEN s.card ELSE m.card END AS card,
    CASE WHEN NOT s.__jetstream__deleted THEN s.digitalWalletToken ELSE m.digitalWalletToken END AS digitalWalletToken,
    CASE WHEN NOT s.__jetstream__deleted THEN s.feeRate ELSE m.feeRate END AS feeRate,
    CASE WHEN NOT s.__jetstream__deleted THEN s.additionalAmount ELSE m.additionalAmount END AS additionalAmount,
    CASE WHEN NOT s.__jetstream__deleted THEN s.cardHolder ELSE m.cardHolder END AS cardHolder,
    CASE WHEN NOT s.__jetstream__deleted THEN s.subNetwork ELSE m.subNetwork END AS subNetwork,
    CASE WHEN NOT s.__jetstream__deleted THEN s.batchNumber ELSE m.batchNumber END AS batchNumber,
    CASE WHEN NOT s.__jetstream__deleted THEN s.originator ELSE m.originator END AS originator,
    CASE WHEN NOT s.__jetstream__deleted THEN s.acquirer ELSE m.acquirer END AS acquirer,
    CASE WHEN NOT s.__jetstream__deleted THEN s.itc ELSE m.itc END AS itc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.outstanding ELSE m.outstanding END AS outstanding,
    CASE WHEN NOT s.__jetstream__deleted THEN s.node ELSE m.node END AS node,
    CASE WHEN NOT s.__jetstream__deleted THEN s.duration ELSE m.duration END AS duration,
    CASE WHEN NOT s.__jetstream__deleted THEN s.account ELSE m.account END AS account,
    CASE WHEN NOT s.__jetstream__deleted THEN s.request ELSE m.request END AS request,
    CASE WHEN NOT s.__jetstream__deleted THEN s.rc ELSE m.rc END AS rc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.mcc ELSE m.mcc END AS mcc,
    CASE WHEN NOT s.__jetstream__deleted THEN s.localId ELSE m.localId END AS localId,
    CASE WHEN NOT s.__jetstream__deleted THEN s.returnedBalances ELSE m.returnedBalances END AS returnedBalances,
    CASE WHEN NOT s.__jetstream__deleted THEN s.localTransactionDate ELSE m.localTransactionDate END AS localTransactionDate,
    CASE WHEN NOT s.__jetstream__deleted THEN s.remoteHost ELSE m.remoteHost END AS remoteHost,
    CASE WHEN NOT s.__jetstream__deleted THEN s.ca_storeNumber ELSE m.ca_storeNumber END AS ca_storeNumber,
    CASE WHEN NOT s.__jetstream__deleted THEN s.account2 ELSE m.account2 END AS account2
FROM staging_cdc_marqeta_jcard_tranlog_history s
LEFT JOIN tranlog m
    ON m.__jetstream__prg_id = s.__jetstream__prg_id
    AND m.__jetstream__shard_id = s.__jetstream__shard_id
    AND m.id = s.id
WHERE (
    (
        m.__jetstream__server_uuid = 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
        AND s.__jetstream__server_uuid = 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
        AND m.__jetstream__server_uuid = s.__jetstream__server_uuid
        AND s.__jetstream__source_ts > COALESCE(m.__jetstream__source_ts, TO_TIMESTAMP(0))
    )
    OR
    (
        NOT s.__jetstream__snapshot
        AND s.__jetstream__server_uuid != 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
        AND (
            m.__jetstream__server_uuid IS NULL
            OR m.__jetstream__server_uuid = s.__jetstream__server_uuid
            OR (
                m.__jetstream__server_uuid != s.__jetstream__server_uuid
                AND COALESCE(m.__jetstream__source_ts, TO_TIMESTAMP(0)) < s.__jetstream__source_ts
            )
        )
    )
    OR m.__jetstream__prg_id IS NULL
)
