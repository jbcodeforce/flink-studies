CREATE TEMP TABLE "JETSTREAM_JCARD_REPLICA"."STAGING_CDC_MARQETA_JCARD_TRANLOG_HISTORY_5764770351815294" AS
    WITH 
    RANKED_BY_TRANSACTION_ALL AS (
            SELECT
                RECORD_CONTENT:prg_id AS "__jetstream__prg_id",
RECORD_CONTENT:shard_id AS "__jetstream__shard_id",
TO_TIMESTAMP_NTZ(RECORD_CONTENT:entry_createdate) AS "__jetstream__entry_createdate",
RECORD_CONTENT:op = 'd' AS "__jetstream__deleted",
SYSDATE() AS "__jetstream__loaded_at",
TO_TIMESTAMP_NTZ(CAST(RECORD_CONTENT:source:ts_ms AS NUMBER), 3) AS "__jetstream__source_ts",
RECORD_CONTENT:transaction:id AS "__jetstream__transaction_id",
RECORD_CONTENT:source:gtid AS "__jetstream__gtid",
RECORD_METADATA:offset AS "__jetstream__offset",
RECORD_METADATA:partition AS "__jetstream__partition",
RECORD_METADATA:key AS "__jetstream__key",
TO_TIMESTAMP_NTZ(CAST(RECORD_CONTENT:ts_ms AS NUMBER), 3) AS "__jetstream__ts",
RECORD_CONTENT:transaction:total_order AS "__jetstream__total_order",
RECORD_CONTENT:transaction:data_collection_order AS "__jetstream__data_collection_order",
RECORD_CONTENT:source:name AS "__jetstream__source_name",
RECORD_CONTENT:source:db AS "__jetstream__source_db",
RECORD_CONTENT:source:table AS "__jetstream__source_table",
RECORD_CONTENT:"server_uuid"::TEXT AS "__jetstream__server_uuid",
RECORD_CONTENT:"server_transaction_id"::INTEGER AS "__jetstream__server_transaction_id",
RECORD_CONTENT:"op" AS "__jetstream__op",
COALESCE(TRY_CAST(RECORD_CONTENT:"source":"snapshot"::VARCHAR AS BOOLEAN), TRUE) AS "__jetstream__snapshot",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_street" ELSE RECORD_CONTENT:after:"ca_street" END AS TEXT) AS "ca_street",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"response" ELSE RECORD_CONTENT:after:"response" END AS TEXT) AS "response",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"transactionState" ELSE RECORD_CONTENT:after:"transactionState" END AS TEXT) AS "transactionState",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"reversalCount" ELSE RECORD_CONTENT:after:"reversalCount" END AS NUMBER(38, 0)) AS "reversalCount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"retrievalReferenceNumber" ELSE RECORD_CONTENT:after:"retrievalReferenceNumber" END AS TEXT) AS "retrievalReferenceNumber",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"irc" ELSE RECORD_CONTENT:after:"irc" END AS TEXT) AS "irc",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"displayMessage" ELSE RECORD_CONTENT:after:"displayMessage" END AS TEXT) AS "displayMessage",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"glTransaction" ELSE RECORD_CONTENT:after:"glTransaction" END AS NUMBER(38, 0)) AS "glTransaction",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"refId" ELSE RECORD_CONTENT:after:"refId" END AS NUMBER(38, 0)) AS "refId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"networkReferenceId" ELSE RECORD_CONTENT:after:"networkReferenceId" END AS TEXT) AS "networkReferenceId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"voidCount" ELSE RECORD_CONTENT:after:"voidCount" END AS NUMBER(38, 0)) AS "voidCount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"issuerFee" ELSE RECORD_CONTENT:after:"issuerFee" END AS NUMBER(38, 4)) AS "issuerFee",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"voidId" ELSE RECORD_CONTENT:after:"voidId" END AS NUMBER(38, 0)) AS "voidId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"createdTime" ELSE RECORD_CONTENT:after:"createdTime" END AS TIMESTAMP_NTZ) AS "createdTime",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"actingCardHolder" ELSE RECORD_CONTENT:after:"actingCardHolder" END AS NUMBER(38, 0)) AS "actingCardHolder",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"network" ELSE RECORD_CONTENT:after:"network" END AS TEXT) AS "network",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"amount" ELSE RECORD_CONTENT:after:"amount" END AS NUMBER(38, 2)) AS "amount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"tags" ELSE RECORD_CONTENT:after:"tags" END AS TEXT) AS "tags",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"gatewaylog" ELSE RECORD_CONTENT:after:"gatewaylog" END AS NUMBER(38, 0)) AS "gatewaylog",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"networkMid" ELSE RECORD_CONTENT:after:"networkMid" END AS TEXT) AS "networkMid",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"lastModifiedTime" ELSE RECORD_CONTENT:after:"lastModifiedTime" END AS TIMESTAMP_NTZ) AS "lastModifiedTime",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"mid" ELSE RECORD_CONTENT:after:"mid" END AS TEXT) AS "mid",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_mallName" ELSE RECORD_CONTENT:after:"ca_mallName" END AS TEXT) AS "ca_mallName",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"id" ELSE RECORD_CONTENT:after:"id" END AS NUMBER(38, 0)) AS "id",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"multiClearCount" ELSE RECORD_CONTENT:after:"multiClearCount" END AS NUMBER(38, 0)) AS "multiClearCount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"committedUsed" ELSE RECORD_CONTENT:after:"committedUsed" END AS NUMBER(38, 2)) AS "committedUsed",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_city" ELSE RECORD_CONTENT:after:"ca_city" END AS TEXT) AS "ca_city",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"responseAmount" ELSE RECORD_CONTENT:after:"responseAmount" END AS NUMBER(38, 2)) AS "responseAmount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"requestAmount" ELSE RECORD_CONTENT:after:"requestAmount" END AS NUMBER(38, 2)) AS "requestAmount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"originalItc" ELSE RECORD_CONTENT:after:"originalItc" END AS TEXT) AS "originalItc",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"extrc" ELSE RECORD_CONTENT:after:"extrc" END AS TEXT) AS "extrc",
CAST(DATEADD('milliseconds', CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"date" ELSE RECORD_CONTENT:after:"date" END, '1970-01-01') AS TIMESTAMP_NTZ) AS "date",
CAST(DATEADD('milliseconds', CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"transmissionDate" ELSE RECORD_CONTENT:after:"transmissionDate" END, '1970-01-01') AS TIMESTAMP_NTZ) AS "transmissionDate",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"completionId" ELSE RECORD_CONTENT:after:"completionId" END AS NUMBER(38, 0)) AS "completionId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"stan" ELSE RECORD_CONTENT:after:"stan" END AS TEXT) AS "stan",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"acquirerReferenceId" ELSE RECORD_CONTENT:after:"acquirerReferenceId" END AS TEXT) AS "acquirerReferenceId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"responseCode" ELSE RECORD_CONTENT:after:"responseCode" END AS TEXT) AS "responseCode",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"completionCount" ELSE RECORD_CONTENT:after:"completionCount" END AS NUMBER(38, 0)) AS "completionCount",
CAST(DATEADD('days', CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"captureDate" ELSE RECORD_CONTENT:after:"captureDate" END, '1970-01-01') AS DATE) AS "captureDate",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"reversalId" ELSE RECORD_CONTENT:after:"reversalId" END AS NUMBER(38, 0)) AS "reversalId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"expirationTime" ELSE RECORD_CONTENT:after:"expirationTime" END AS TIMESTAMP_NTZ) AS "expirationTime",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"fileName" ELSE RECORD_CONTENT:after:"fileName" END AS TEXT) AS "fileName",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_zip" ELSE RECORD_CONTENT:after:"ca_zip" END AS TEXT) AS "ca_zip",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"currencyCode" ELSE RECORD_CONTENT:after:"currencyCode" END AS TEXT) AS "currencyCode",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"tid" ELSE RECORD_CONTENT:after:"tid" END AS TEXT) AS "tid",
CAST(DATEADD('days', CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"settlementDate" ELSE RECORD_CONTENT:after:"settlementDate" END, '1970-01-01') AS DATE) AS "settlementDate",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_region" ELSE RECORD_CONTENT:after:"ca_region" END AS TEXT) AS "ca_region",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"acquirerFee" ELSE RECORD_CONTENT:after:"acquirerFee" END AS NUMBER(38, 4)) AS "acquirerFee",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"functionCode" ELSE RECORD_CONTENT:after:"functionCode" END AS TEXT) AS "functionCode",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_country" ELSE RECORD_CONTENT:after:"ca_country" END AS TEXT) AS "ca_country",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_name" ELSE RECORD_CONTENT:after:"ca_name" END AS TEXT) AS "ca_name",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"forwardingInstId" ELSE RECORD_CONTENT:after:"forwardingInstId" END AS TEXT) AS "forwardingInstId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"approvalNumber" ELSE RECORD_CONTENT:after:"approvalNumber" END AS TEXT) AS "approvalNumber",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"incomingNetworkRequestITC" ELSE RECORD_CONTENT:after:"incomingNetworkRequestITC" END AS TEXT) AS "incomingNetworkRequestITC",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"adviceId" ELSE RECORD_CONTENT:after:"adviceId" END AS NUMBER(38, 0)) AS "adviceId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"reasonCode" ELSE RECORD_CONTENT:after:"reasonCode" END AS TEXT) AS "reasonCode",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"card" ELSE RECORD_CONTENT:after:"card" END AS NUMBER(38, 0)) AS "card",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"digitalWalletToken" ELSE RECORD_CONTENT:after:"digitalWalletToken" END AS NUMBER(38, 0)) AS "digitalWalletToken",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"feeRate" ELSE RECORD_CONTENT:after:"feeRate" END AS NUMBER(38, 3)) AS "feeRate",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"additionalAmount" ELSE RECORD_CONTENT:after:"additionalAmount" END AS NUMBER(38, 2)) AS "additionalAmount",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"cardHolder" ELSE RECORD_CONTENT:after:"cardHolder" END AS NUMBER(38, 0)) AS "cardHolder",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"subNetwork" ELSE RECORD_CONTENT:after:"subNetwork" END AS TEXT) AS "subNetwork",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"batchNumber" ELSE RECORD_CONTENT:after:"batchNumber" END AS NUMBER(38, 0)) AS "batchNumber",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"originator" ELSE RECORD_CONTENT:after:"originator" END AS TEXT) AS "originator",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"acquirer" ELSE RECORD_CONTENT:after:"acquirer" END AS TEXT) AS "acquirer",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"itc" ELSE RECORD_CONTENT:after:"itc" END AS TEXT) AS "itc",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"outstanding" ELSE RECORD_CONTENT:after:"outstanding" END AS NUMBER(38, 0)) AS "outstanding",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"node" ELSE RECORD_CONTENT:after:"node" END AS TEXT) AS "node",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"duration" ELSE RECORD_CONTENT:after:"duration" END AS NUMBER(38, 0)) AS "duration",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"account" ELSE RECORD_CONTENT:after:"account" END AS NUMBER(38, 0)) AS "account",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"request" ELSE RECORD_CONTENT:after:"request" END AS TEXT) AS "request",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"rc" ELSE RECORD_CONTENT:after:"rc" END AS TEXT) AS "rc",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"mcc" ELSE RECORD_CONTENT:after:"mcc" END AS TEXT) AS "mcc",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"localId" ELSE RECORD_CONTENT:after:"localId" END AS NUMBER(38, 0)) AS "localId",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"returnedBalances" ELSE RECORD_CONTENT:after:"returnedBalances" END AS TEXT) AS "returnedBalances",
CAST(DATEADD('milliseconds', CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"localTransactionDate" ELSE RECORD_CONTENT:after:"localTransactionDate" END, '1970-01-01') AS TIMESTAMP_NTZ) AS "localTransactionDate",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"remoteHost" ELSE RECORD_CONTENT:after:"remoteHost" END AS TEXT) AS "remoteHost",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"ca_storeNumber" ELSE RECORD_CONTENT:after:"ca_storeNumber" END AS TEXT) AS "ca_storeNumber",
CAST(CASE WHEN RECORD_CONTENT:op = 'd' THEN RECORD_CONTENT:before:"account2" ELSE RECORD_CONTENT:after:"account2" END AS NUMBER(38, 0)) AS "account2",
                ROW_NUMBER() OVER (
                    PARTITION BY "__jetstream__prg_id",
"__jetstream__shard_id",
"id",
                        RECORD_CONTENT:"server_uuid"::TEXT
                    ORDER BY
                        RECORD_CONTENT:"server_transaction_id"::INTEGER DESC,
                        RECORD_CONTENT:"source":"pos"::INTEGER DESC,
                        RECORD_CONTENT:"transaction":"data_collection_order"::INTEGER DESC
                ) AS TRANSACTION_RANK
            FROM
                "JETSTREAM_JCARD_HISTORY"."CDC_MARQETA_JCARD_TRANLOG_HISTORY" h
            WHERE RECORD_CONTENT:"server_uuid"::TEXT != 'NA' AND ((RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_1:1000') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_1:1034'), 0) AND TRANSACTION_ID('server_uuid_1:1000')))
        ), RANKED_BY_TS_ALL AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY "__jetstream__prg_id",
"__jetstream__shard_id",
"id"
                    ORDER BY
                        "__jetstream__source_ts" DESC
                ) AS TS_RANK
            FROM
                RANKED_BY_TRANSACTION_ALL
            WHERE
                TRANSACTION_RANK = 1
            )


    
    
        SELECT
            *
        FROM
            RANKED_BY_TS_ALL
        WHERE
            TS_RANK = 1
----------------------------------------------------------------------------------------------------
Query Text:
MERGE INTO "JETSTREAM_JCARD_REPLICA"."TRANLOG" m
        USING ("JETSTREAM_JCARD_REPLICA"."STAGING_CDC_MARQETA_JCARD_TRANLOG_HISTORY_5764770351815294") AS s
        ON m."__jetstream__prg_id" = s."__jetstream__prg_id"
AND m."__jetstream__shard_id" = s."__jetstream__shard_id"
AND m."id" = s."id"
        WHEN MATCHED
            AND
            (
                (
                    -- SQC9
                    (
                        m."__jetstream__server_uuid" = 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
                        AND s."__jetstream__server_uuid" = 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
                        AND m."__jetstream__server_uuid" = s."__jetstream__server_uuid"
                        AND s."__jetstream__source_ts" > COALESCE(m."__jetstream__source_ts", TO_TIMESTAMP_NTZ(0))
                    )
                )
                OR
                (
                    -- NON SQC9
                    NOT s."__jetstream__snapshot"
                    AND s."__jetstream__server_uuid" != 'aa59824f-92f7-11ef-8693-02c610bf8511_2709'
                    -- this prevents snapshot data from overwriting non-snapshot data
                    AND (
                        m."__jetstream__server_uuid" IS NULL -- always overwrite hevo data
                        OR m."__jetstream__server_uuid" = s."__jetstream__server_uuid"
                        OR (
                            m."__jetstream__server_uuid" != s."__jetstream__server_uuid"
                            AND COALESCE(m."__jetstream__source_ts", TO_TIMESTAMP_NTZ(0)) < s."__jetstream__source_ts"
                        )
                    )
                )
            )
            THEN UPDATE SET m."__jetstream__prg_id" = s."__jetstream__prg_id",
m."__jetstream__shard_id" = s."__jetstream__shard_id",
m."__jetstream__entry_createdate" = s."__jetstream__entry_createdate",
m."__jetstream__deleted" = s."__jetstream__deleted",
m."__jetstream__loaded_at" = s."__jetstream__loaded_at",
m."__jetstream__source_ts" = s."__jetstream__source_ts",
m."__jetstream__transaction_id" = s."__jetstream__transaction_id",
m."__jetstream__gtid" = s."__jetstream__gtid",
m."__jetstream__offset" = s."__jetstream__offset",
m."__jetstream__partition" = s."__jetstream__partition",
m."__jetstream__key" = s."__jetstream__key",
m."__jetstream__ts" = s."__jetstream__ts",
m."__jetstream__total_order" = s."__jetstream__total_order",
m."__jetstream__data_collection_order" = s."__jetstream__data_collection_order",
m."__jetstream__source_name" = s."__jetstream__source_name",
m."__jetstream__source_db" = s."__jetstream__source_db",
m."__jetstream__source_table" = s."__jetstream__source_table",
m."__jetstream__server_uuid" = s."__jetstream__server_uuid",
m."__jetstream__server_transaction_id" = s."__jetstream__server_transaction_id",
m."__jetstream__op" = s."__jetstream__op",
m."__jetstream__snapshot" = s."__jetstream__snapshot",
m."ca_street" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_street" ELSE m."ca_street" END,
m."response" = CASE WHEN NOT s."__jetstream__deleted" THEN s."response" ELSE m."response" END,
m."transactionState" = CASE WHEN NOT s."__jetstream__deleted" THEN s."transactionState" ELSE m."transactionState" END,
m."reversalCount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."reversalCount" ELSE m."reversalCount" END,
m."retrievalReferenceNumber" = CASE WHEN NOT s."__jetstream__deleted" THEN s."retrievalReferenceNumber" ELSE m."retrievalReferenceNumber" END,
m."irc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."irc" ELSE m."irc" END,
m."displayMessage" = CASE WHEN NOT s."__jetstream__deleted" THEN s."displayMessage" ELSE m."displayMessage" END,
m."glTransaction" = CASE WHEN NOT s."__jetstream__deleted" THEN s."glTransaction" ELSE m."glTransaction" END,
m."refId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."refId" ELSE m."refId" END,
m."networkReferenceId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."networkReferenceId" ELSE m."networkReferenceId" END,
m."voidCount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."voidCount" ELSE m."voidCount" END,
m."issuerFee" = CASE WHEN NOT s."__jetstream__deleted" THEN s."issuerFee" ELSE m."issuerFee" END,
m."voidId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."voidId" ELSE m."voidId" END,
m."createdTime" = CASE WHEN NOT s."__jetstream__deleted" THEN s."createdTime" ELSE m."createdTime" END,
m."actingCardHolder" = CASE WHEN NOT s."__jetstream__deleted" THEN s."actingCardHolder" ELSE m."actingCardHolder" END,
m."network" = CASE WHEN NOT s."__jetstream__deleted" THEN s."network" ELSE m."network" END,
m."amount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."amount" ELSE m."amount" END,
m."tags" = CASE WHEN NOT s."__jetstream__deleted" THEN s."tags" ELSE m."tags" END,
m."gatewaylog" = CASE WHEN NOT s."__jetstream__deleted" THEN s."gatewaylog" ELSE m."gatewaylog" END,
m."networkMid" = CASE WHEN NOT s."__jetstream__deleted" THEN s."networkMid" ELSE m."networkMid" END,
m."lastModifiedTime" = CASE WHEN NOT s."__jetstream__deleted" THEN s."lastModifiedTime" ELSE m."lastModifiedTime" END,
m."mid" = CASE WHEN NOT s."__jetstream__deleted" THEN s."mid" ELSE m."mid" END,
m."ca_mallName" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_mallName" ELSE m."ca_mallName" END,
m."id" = CASE WHEN NOT s."__jetstream__deleted" THEN s."id" ELSE m."id" END,
m."multiClearCount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."multiClearCount" ELSE m."multiClearCount" END,
m."committedUsed" = CASE WHEN NOT s."__jetstream__deleted" THEN s."committedUsed" ELSE m."committedUsed" END,
m."ca_city" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_city" ELSE m."ca_city" END,
m."responseAmount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."responseAmount" ELSE m."responseAmount" END,
m."requestAmount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."requestAmount" ELSE m."requestAmount" END,
m."originalItc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."originalItc" ELSE m."originalItc" END,
m."extrc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."extrc" ELSE m."extrc" END,
m."date" = CASE WHEN NOT s."__jetstream__deleted" THEN s."date" ELSE m."date" END,
m."transmissionDate" = CASE WHEN NOT s."__jetstream__deleted" THEN s."transmissionDate" ELSE m."transmissionDate" END,
m."completionId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."completionId" ELSE m."completionId" END,
m."stan" = CASE WHEN NOT s."__jetstream__deleted" THEN s."stan" ELSE m."stan" END,
m."acquirerReferenceId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."acquirerReferenceId" ELSE m."acquirerReferenceId" END,
m."responseCode" = CASE WHEN NOT s."__jetstream__deleted" THEN s."responseCode" ELSE m."responseCode" END,
m."completionCount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."completionCount" ELSE m."completionCount" END,
m."captureDate" = CASE WHEN NOT s."__jetstream__deleted" THEN s."captureDate" ELSE m."captureDate" END,
m."reversalId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."reversalId" ELSE m."reversalId" END,
m."expirationTime" = CASE WHEN NOT s."__jetstream__deleted" THEN s."expirationTime" ELSE m."expirationTime" END,
m."fileName" = CASE WHEN NOT s."__jetstream__deleted" THEN s."fileName" ELSE m."fileName" END,
m."ca_zip" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_zip" ELSE m."ca_zip" END,
m."currencyCode" = CASE WHEN NOT s."__jetstream__deleted" THEN s."currencyCode" ELSE m."currencyCode" END,
m."tid" = CASE WHEN NOT s."__jetstream__deleted" THEN s."tid" ELSE m."tid" END,
m."settlementDate" = CASE WHEN NOT s."__jetstream__deleted" THEN s."settlementDate" ELSE m."settlementDate" END,
m."ca_region" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_region" ELSE m."ca_region" END,
m."acquirerFee" = CASE WHEN NOT s."__jetstream__deleted" THEN s."acquirerFee" ELSE m."acquirerFee" END,
m."functionCode" = CASE WHEN NOT s."__jetstream__deleted" THEN s."functionCode" ELSE m."functionCode" END,
m."ca_country" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_country" ELSE m."ca_country" END,
m."ca_name" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_name" ELSE m."ca_name" END,
m."forwardingInstId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."forwardingInstId" ELSE m."forwardingInstId" END,
m."approvalNumber" = CASE WHEN NOT s."__jetstream__deleted" THEN s."approvalNumber" ELSE m."approvalNumber" END,
m."incomingNetworkRequestITC" = CASE WHEN NOT s."__jetstream__deleted" THEN s."incomingNetworkRequestITC" ELSE m."incomingNetworkRequestITC" END,
m."adviceId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."adviceId" ELSE m."adviceId" END,
m."reasonCode" = CASE WHEN NOT s."__jetstream__deleted" THEN s."reasonCode" ELSE m."reasonCode" END,
m."card" = CASE WHEN NOT s."__jetstream__deleted" THEN s."card" ELSE m."card" END,
m."digitalWalletToken" = CASE WHEN NOT s."__jetstream__deleted" THEN s."digitalWalletToken" ELSE m."digitalWalletToken" END,
m."feeRate" = CASE WHEN NOT s."__jetstream__deleted" THEN s."feeRate" ELSE m."feeRate" END,
m."additionalAmount" = CASE WHEN NOT s."__jetstream__deleted" THEN s."additionalAmount" ELSE m."additionalAmount" END,
m."cardHolder" = CASE WHEN NOT s."__jetstream__deleted" THEN s."cardHolder" ELSE m."cardHolder" END,
m."subNetwork" = CASE WHEN NOT s."__jetstream__deleted" THEN s."subNetwork" ELSE m."subNetwork" END,
m."batchNumber" = CASE WHEN NOT s."__jetstream__deleted" THEN s."batchNumber" ELSE m."batchNumber" END,
m."originator" = CASE WHEN NOT s."__jetstream__deleted" THEN s."originator" ELSE m."originator" END,
m."acquirer" = CASE WHEN NOT s."__jetstream__deleted" THEN s."acquirer" ELSE m."acquirer" END,
m."itc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."itc" ELSE m."itc" END,
m."outstanding" = CASE WHEN NOT s."__jetstream__deleted" THEN s."outstanding" ELSE m."outstanding" END,
m."node" = CASE WHEN NOT s."__jetstream__deleted" THEN s."node" ELSE m."node" END,
m."duration" = CASE WHEN NOT s."__jetstream__deleted" THEN s."duration" ELSE m."duration" END,
m."account" = CASE WHEN NOT s."__jetstream__deleted" THEN s."account" ELSE m."account" END,
m."request" = CASE WHEN NOT s."__jetstream__deleted" THEN s."request" ELSE m."request" END,
m."rc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."rc" ELSE m."rc" END,
m."mcc" = CASE WHEN NOT s."__jetstream__deleted" THEN s."mcc" ELSE m."mcc" END,
m."localId" = CASE WHEN NOT s."__jetstream__deleted" THEN s."localId" ELSE m."localId" END,
m."returnedBalances" = CASE WHEN NOT s."__jetstream__deleted" THEN s."returnedBalances" ELSE m."returnedBalances" END,
m."localTransactionDate" = CASE WHEN NOT s."__jetstream__deleted" THEN s."localTransactionDate" ELSE m."localTransactionDate" END,
m."remoteHost" = CASE WHEN NOT s."__jetstream__deleted" THEN s."remoteHost" ELSE m."remoteHost" END,
m."ca_storeNumber" = CASE WHEN NOT s."__jetstream__deleted" THEN s."ca_storeNumber" ELSE m."ca_storeNumber" END,
m."account2" = CASE WHEN NOT s."__jetstream__deleted" THEN s."account2" ELSE m."account2" END
        WHEN NOT MATCHED
            THEN INSERT ("__jetstream__prg_id",
"__jetstream__shard_id",
"__jetstream__entry_createdate",
"__jetstream__deleted",
"__jetstream__loaded_at",
"__jetstream__source_ts",
"__jetstream__transaction_id",
"__jetstream__gtid",
"__jetstream__offset",
"__jetstream__partition",
"__jetstream__key",
"__jetstream__ts",
"__jetstream__total_order",
"__jetstream__data_collection_order",
"__jetstream__source_name",
"__jetstream__source_db",
"__jetstream__source_table",
"__jetstream__server_uuid",
"__jetstream__server_transaction_id",
"__jetstream__op",
"__jetstream__snapshot",
"ca_street",
"response",
"transactionState",
"reversalCount",
"retrievalReferenceNumber",
"irc",
"displayMessage",
"glTransaction",
"refId",
"networkReferenceId",
"voidCount",
"issuerFee",
"voidId",
"createdTime",
"actingCardHolder",
"network",
"amount",
"tags",
"gatewaylog",
"networkMid",
"lastModifiedTime",
"mid",
"ca_mallName",
"id",
"multiClearCount",
"committedUsed",
"ca_city",
"responseAmount",
"requestAmount",
"originalItc",
"extrc",
"date",
"transmissionDate",
"completionId",
"stan",
"acquirerReferenceId",
"responseCode",
"completionCount",
"captureDate",
"reversalId",
"expirationTime",
"fileName",
"ca_zip",
"currencyCode",
"tid",
"settlementDate",
"ca_region",
"acquirerFee",
"functionCode",
"ca_country",
"ca_name",
"forwardingInstId",
"approvalNumber",
"incomingNetworkRequestITC",
"adviceId",
"reasonCode",
"card",
"digitalWalletToken",
"feeRate",
"additionalAmount",
"cardHolder",
"subNetwork",
"batchNumber",
"originator",
"acquirer",
"itc",
"outstanding",
"node",
"duration",
"account",
"request",
"rc",
"mcc",
"localId",
"returnedBalances",
"localTransactionDate",
"remoteHost",
"ca_storeNumber",
"account2") VALUES (s."__jetstream__prg_id",
s."__jetstream__shard_id",
s."__jetstream__entry_createdate",
s."__jetstream__deleted",
s."__jetstream__loaded_at",
s."__jetstream__source_ts",
s."__jetstream__transaction_id",
s."__jetstream__gtid",
s."__jetstream__offset",
s."__jetstream__partition",
s."__jetstream__key",
s."__jetstream__ts",
s."__jetstream__total_order",
s."__jetstream__data_collection_order",
s."__jetstream__source_name",
s."__jetstream__source_db",
s."__jetstream__source_table",
s."__jetstream__server_uuid",
s."__jetstream__server_transaction_id",
s."__jetstream__op",
s."__jetstream__snapshot",
s."ca_street",
s."response",
s."transactionState",
s."reversalCount",
s."retrievalReferenceNumber",
s."irc",
s."displayMessage",
s."glTransaction",
s."refId",
s."networkReferenceId",
s."voidCount",
s."issuerFee",
s."voidId",
s."createdTime",
s."actingCardHolder",
s."network",
s."amount",
s."tags",
s."gatewaylog",
s."networkMid",
s."lastModifiedTime",
s."mid",
s."ca_mallName",
s."id",
s."multiClearCount",
s."committedUsed",
s."ca_city",
s."responseAmount",
s."requestAmount",
s."originalItc",
s."extrc",
s."date",
s."transmissionDate",
s."completionId",
s."stan",
s."acquirerReferenceId",
s."responseCode",
s."completionCount",
s."captureDate",
s."reversalId",
s."expirationTime",
s."fileName",
s."ca_zip",
s."currencyCode",
s."tid",
s."settlementDate",
s."ca_region",
s."acquirerFee",
s."functionCode",
s."ca_country",
s."ca_name",
s."forwardingInstId",
s."approvalNumber",
s."incomingNetworkRequestITC",
s."adviceId",
s."reasonCode",
s."card",
s."digitalWalletToken",
s."feeRate",
s."additionalAmount",
s."cardHolder",
s."subNetwork",
s."batchNumber",
s."originator",
s."acquirer",
s."itc",
s."outstanding",
s."node",
s."duration",
s."account",
s."request",
s."rc",
s."mcc",
s."localId",
s."returnedBalances",
s."localTransactionDate",
s."remoteHost",
s."ca_storeNumber",
s."account2")

----


            SELECT
                RECORD_CONTENT:"server_uuid"::TEXT AS "server_uuid",
                RECORD_CONTENT:"server_transaction_id"::INTEGER AS "transaction_id",
                RECORD_CONTENT:"entry_createdate"::timestamp AS "entry_createdate",
                0 AS "dml_event_count"
            FROM "JETSTREAM_JCARD_HISTORY"."CDC_MARQETA_JCARD_UBERDDL"
            WHERE
                to_timestamp(record_content:ts_ms::number, 3) >= dateadd(day, -3, current_timestamp())
                AND RECORD_CONTENT:"server_uuid"::TEXT != 'NA'
                AND ((RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_2:1001') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_2:1022'), 0) AND TRANSACTION_ID('server_uuid_2:1001'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_3:1002') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_3:1002'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_4:1003') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_4:1023'), 0) AND TRANSACTION_ID('server_uuid_4:1003'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_5:1004') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_5:1024'), 0) AND TRANSACTION_ID('server_uuid_5:1004'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_6:1005') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_6:1005'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_7:1006') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_7:1025'), 0) AND TRANSACTION_ID('server_uuid_7:1006'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_8:1007') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_8:1007'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_9:1008') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_9:1026'), 0) AND TRANSACTION_ID('server_uuid_9:1008'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_10:1009') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_10:1027'), 0) AND TRANSACTION_ID('server_uuid_10:1009'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_11:1010') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_11:1010'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_12:1011') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_12:1028'), 0) AND TRANSACTION_ID('server_uuid_12:1011'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_13:1012') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_13:1029'), 0) AND TRANSACTION_ID('server_uuid_13:1012'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_14:1013') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_14:1030'), 0) AND TRANSACTION_ID('server_uuid_14:1013'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_15:1014') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_15:1014'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_16:1015') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_16:1015'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_17:1016') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_17:1031'), 0) AND TRANSACTION_ID('server_uuid_17:1016'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_18:1017') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_18:1017'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_19:1018') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_19:1032'), 0) AND TRANSACTION_ID('server_uuid_19:1018'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_20:1019') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_20:1033'), 0) AND TRANSACTION_ID('server_uuid_20:1019'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_21:1020') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_21:1020'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_1:1021') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_1:1034'), 0) AND TRANSACTION_ID('server_uuid_1:1021')))
            UNION ALL
            
SELECT
    RECORD_CONTENT:"server_uuid"::TEXT AS "server_uuid",
    RECORD_CONTENT:"server_transaction_id"::INTEGER AS "transaction_id",
    RECORD_CONTENT:"entry_createdate"::timestamp AS "entry_createdate",
    0 AS "dml_event_count"
FROM "JETSTREAM_JCARD_HISTORY"."CDC_MARQETA_JCARD_DDL"
WHERE
    to_timestamp(record_content:ts_ms::number, 3) >= dateadd(day, -3, current_timestamp())
    AND RECORD_CONTENT:"server_uuid"::TEXT != 'NA'
    AND ((RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_2:1001') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_2:1022'), 0) AND TRANSACTION_ID('server_uuid_2:1001'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_3:1002') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_3:1002'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_4:1003') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_4:1023'), 0) AND TRANSACTION_ID('server_uuid_4:1003'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_5:1004') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_5:1024'), 0) AND TRANSACTION_ID('server_uuid_5:1004'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_6:1005') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_6:1005'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_7:1006') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_7:1025'), 0) AND TRANSACTION_ID('server_uuid_7:1006'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_8:1007') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_8:1007'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_9:1008') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_9:1026'), 0) AND TRANSACTION_ID('server_uuid_9:1008'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_10:1009') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_10:1027'), 0) AND TRANSACTION_ID('server_uuid_10:1009'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_11:1010') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_11:1010'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_12:1011') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_12:1028'), 0) AND TRANSACTION_ID('server_uuid_12:1011'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_13:1012') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_13:1029'), 0) AND TRANSACTION_ID('server_uuid_13:1012'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_14:1013') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_14:1030'), 0) AND TRANSACTION_ID('server_uuid_14:1013'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_15:1014') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_15:1014'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_16:1015') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_16:1015'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_17:1016') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_17:1031'), 0) AND TRANSACTION_ID('server_uuid_17:1016'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_18:1017') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_18:1017'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_19:1018') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_19:1032'), 0) AND TRANSACTION_ID('server_uuid_19:1018'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_20:1019') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_20:1033'), 0) AND TRANSACTION_ID('server_uuid_20:1019'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_21:1020') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_21:1020'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_1:1021') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_1:1034'), 0) AND TRANSACTION_ID('server_uuid_1:1021')))
UNION ALL
SELECT
    RECORD_CONTENT:"server_uuid"::TEXT AS "server_uuid",
    RECORD_CONTENT:"server_transaction_id"::INTEGER AS "transaction_id",
    RECORD_CONTENT:"entry_createdate"::timestamp AS "entry_createdate",
    COALESCE(e.VALUE:"event_count", 0) AS "dml_event_count"
FROM "JETSTREAM_JCARD_HISTORY"."CDC_MARQETA_JCARD_DBTRANSACTION" h
JOIN TABLE(FLATTEN(input=>ARRAY_APPEND(
            h.RECORD_CONTENT:data_collections,
            PARSE_JSON('{"data_collection": "dummy.tranlog", "event_count": 0}')
        ))) e -- If a transaction does not touch the source table, flatten returns 0 rows
WHERE
    to_timestamp(record_content:ts_ms::number, 3) >= dateadd(day, -3, current_timestamp())
    AND RECORD_CONTENT:"server_uuid"::TEXT != 'NA'
    AND SPLIT_PART(e.VALUE:data_collection, '.', 2) = 'tranlog'
    AND RECORD_CONTENT:status = 'END'
    AND ((RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_2:1001') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_2:1022'), 0) AND TRANSACTION_ID('server_uuid_2:1001'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_3:1002') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_3:1002'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_4:1003') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_4:1023'), 0) AND TRANSACTION_ID('server_uuid_4:1003'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_5:1004') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_5:1024'), 0) AND TRANSACTION_ID('server_uuid_5:1004'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_6:1005') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_6:1005'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_7:1006') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_7:1025'), 0) AND TRANSACTION_ID('server_uuid_7:1006'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_8:1007') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_8:1007'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_9:1008') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_9:1026'), 0) AND TRANSACTION_ID('server_uuid_9:1008'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_10:1009') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_10:1027'), 0) AND TRANSACTION_ID('server_uuid_10:1009'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_11:1010') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_11:1010'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_12:1011') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_12:1028'), 0) AND TRANSACTION_ID('server_uuid_12:1011'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_13:1012') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_13:1029'), 0) AND TRANSACTION_ID('server_uuid_13:1012'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_14:1013') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_14:1030'), 0) AND TRANSACTION_ID('server_uuid_14:1013'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_15:1014') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_15:1014'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_16:1015') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_16:1015'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_17:1016') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_17:1031'), 0) AND TRANSACTION_ID('server_uuid_17:1016'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_18:1017') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_18:1017'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_19:1018') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_19:1032'), 0) AND TRANSACTION_ID('server_uuid_19:1018'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_20:1019') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_20:1033'), 0) AND TRANSACTION_ID('server_uuid_20:1019'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_21:1020') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_21:1020'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_1:1021') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_1:1034'), 0) AND TRANSACTION_ID('server_uuid_1:1021')))
), TRANSACTIONS_COUNTS AS (
SELECT
    "server_uuid",
    "transaction_id",
    MAX("dml_event_count") AS "dml_event_count",
    MAX("entry_createdate") AS "entry_createdate"
FROM ALL_TRANSACTIONS
GROUP BY
    "server_uuid",
    "transaction_id"
), EVENTS_COUNTS AS (
SELECT
    RECORD_CONTENT:"server_uuid"::TEXT AS "server_uuid",
    RECORD_CONTENT:"server_transaction_id"::INTEGER AS "transaction_id",
    COUNT(DISTINCT
        RECORD_CONTENT:"source":"pos"::INTEGER,
        RECORD_CONTENT:"transaction":"data_collection_order"::INTEGER
    ) AS "dml_event_count"
FROM "JETSTREAM_JCARD_HISTORY"."CDC_MARQETA_JCARD_TRANLOG_HISTORY"
WHERE
    to_timestamp(record_content:ts_ms::number, 3) >= dateadd(day, -3, current_timestamp())
    AND RECORD_CONTENT:"server_uuid"::TEXT != 'NA'
    AND ((RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_2:1001') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_2:1022'), 0) AND TRANSACTION_ID('server_uuid_2:1001'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_3:1002') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_3:1002'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_4:1003') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_4:1023'), 0) AND TRANSACTION_ID('server_uuid_4:1003'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_5:1004') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_5:1024'), 0) AND TRANSACTION_ID('server_uuid_5:1004'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_6:1005') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_6:1005'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_7:1006') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_7:1025'), 0) AND TRANSACTION_ID('server_uuid_7:1006'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_8:1007') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_8:1007'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_9:1008') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_9:1026'), 0) AND TRANSACTION_ID('server_uuid_9:1008'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_10:1009') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_10:1027'), 0) AND TRANSACTION_ID('server_uuid_10:1009'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_11:1010') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_11:1010'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_12:1011') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_12:1028'), 0) AND TRANSACTION_ID('server_uuid_12:1011'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_13:1012') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_13:1029'), 0) AND TRANSACTION_ID('server_uuid_13:1012'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_14:1013') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_14:1030'), 0) AND TRANSACTION_ID('server_uuid_14:1013'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_15:1014') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_15:1014'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_16:1015') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_16:1015'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_17:1016') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_17:1031'), 0) AND TRANSACTION_ID('server_uuid_17:1016'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_18:1017') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_18:1017'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_19:1018') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_19:1032'), 0) AND TRANSACTION_ID('server_uuid_19:1018'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_20:1019') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_20:1033'), 0) AND TRANSACTION_ID('server_uuid_20:1019'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_21:1020') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID(''), 0) AND TRANSACTION_ID('server_uuid_21:1020'))
OR (RECORD_CONTENT:"server_uuid"::TEXT = SERVER_UUID('server_uuid_1:1021') AND RECORD_CONTENT:"server_transaction_id"::INTEGER BETWEEN COALESCE(TRANSACTION_ID('server_uuid_1:1034'), 0) AND TRANSACTION_ID('server_uuid_1:1021')))
GROUP BY
    "server_uuid",
    "transaction_id"
), GROUPS AS (
SELECT
    t."server_uuid",
    t."transaction_id",
    "entry_createdate" <= DATEADD(HOUR, -2, CURRENT_TIMESTAMP()) AS "old_enough",
    CASE WHEN NOT "old_enough"
        THEN MIN(t."transaction_id") OVER (PARTITION BY t."server_uuid", "old_enough")
    END AS "new_start",
    SUM(
        CASE WHEN t."dml_event_count" <= COALESCE(e."dml_event_count", 0)
            THEN 0 -- go/jetstream_etl_dco_bug
            ELSE t."dml_event_count" - COALESCE(e."dml_event_count", 0)
        END
    ) OVER (PARTITION BY t."server_uuid" ORDER BY t."transaction_id") AS "cumulative_missing_events",
    CASE WHEN t."dml_event_count" < COALESCE(e."dml_event_count", 0)
        THEN 1
        ELSE 0
    END AS "overcomplete",
    CASE t."server_uuid"
        WHEN SERVER_UUID('server_uuid_2:1022') THEN TRANSACTION_ID('server_uuid_2:1022')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_4:1023') THEN TRANSACTION_ID('server_uuid_4:1023')
WHEN SERVER_UUID('server_uuid_5:1024') THEN TRANSACTION_ID('server_uuid_5:1024')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_7:1025') THEN TRANSACTION_ID('server_uuid_7:1025')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_9:1026') THEN TRANSACTION_ID('server_uuid_9:1026')
WHEN SERVER_UUID('server_uuid_10:1027') THEN TRANSACTION_ID('server_uuid_10:1027')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_12:1028') THEN TRANSACTION_ID('server_uuid_12:1028')
WHEN SERVER_UUID('server_uuid_13:1029') THEN TRANSACTION_ID('server_uuid_13:1029')
WHEN SERVER_UUID('server_uuid_14:1030') THEN TRANSACTION_ID('server_uuid_14:1030')
WHEN '' THEN NULL
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_17:1031') THEN TRANSACTION_ID('server_uuid_17:1031')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_19:1032') THEN TRANSACTION_ID('server_uuid_19:1032')
WHEN SERVER_UUID('server_uuid_20:1033') THEN TRANSACTION_ID('server_uuid_20:1033')
WHEN '' THEN NULL
WHEN SERVER_UUID('server_uuid_1:1034') THEN TRANSACTION_ID('server_uuid_1:1034')
    END AS "transaction_id_offset",
    DENSE_RANK() OVER (
        PARTITION BY t."server_uuid",
            "old_enough"
        ORDER BY t."transaction_id"
        ) - 1
    AS "relative_transaction_order"
FROM TRANSACTIONS_COUNTS t
LEFT JOIN EVENTS_COUNTS e
    ON t."server_uuid" = e."server_uuid"
    AND t."transaction_id" = e."transaction_id"
), INTERVALS AS (
SELECT
    "server_uuid",
    MIN("transaction_id") AS "begin",
    MAX("transaction_id") AS "end",
    "cumulative_missing_events" = 0 AS "complete",
    SUM("overcomplete") AS "overcomplete_transactions",
    "transaction_id" - "relative_transaction_order" = "new_start" AS "contiguous",
    CASE WHEN "old_enough"
        THEN "transaction_id" - "relative_transaction_order" - "transaction_id_offset"
    END AS "cumulative_old_missing_transactions",
    "old_enough",
    "complete" AND ("contiguous" OR "old_enough") AS "loadable"
FROM GROUPS
GROUP BY
    "complete",
    "cumulative_old_missing_transactions",
    "contiguous",
    "server_uuid",
    "transaction_id_offset",
    "old_enough"
)
SELECT
    "server_uuid",
    MIN(CASE WHEN "loadable" THEN "begin" END) AS "loadable_begin",
    MAX(CASE WHEN "loadable" THEN "end" END) AS "loadable_end",
    MIN(CASE WHEN "complete" THEN "begin" END) AS "complete_begin",
    MAX(CASE WHEN "complete" THEN "end" END) AS "complete_end",
    MIN(CASE WHEN NOT "complete" THEN "begin" END) AS "incomplete_begin",
    MAX(CASE WHEN NOT "complete" THEN "end" END) AS "incomplete_end",
    MIN(CASE WHEN "contiguous" THEN "begin" END) AS "contiguous_begin",
    MAX(CASE WHEN "contiguous" THEN "end" END) AS "contiguous_end",
    MIN(CASE WHEN NOT "contiguous" THEN "begin" END) AS "noncontiguous_begin",
    MAX(CASE WHEN NOT "contiguous" THEN "end" END) AS "noncontiguous_end",
    MIN(CASE WHEN "old_enough" THEN "begin" END) AS "old_enough_begin",
    MAX(CASE WHEN "old_enough" THEN "end" END) AS "old_enough_end",
    ARRAY_AGG(CASE WHEN "loadable" THEN OBJECT_CONSTRUCT('begin', "begin", 'end', "end") END) AS "loadable_ranges",
    -- TODO: if there are many missing gtids in the "old enough" category, "loadable_ranges" could be large
    COALESCE(MAX("cumulative_old_missing_transactions"), 0) AS "missing_old_transactions",
    SUM("overcomplete_transactions") AS "overcomplete_transactions"
FROM INTERVALS
GROUP BY "server_uuid"
;