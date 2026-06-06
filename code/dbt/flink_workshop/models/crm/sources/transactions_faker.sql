{{ config(
    materialized='streaming_source',
    connector='faker',
    statement_name='fw_crm_transactions_faker',
    tags=['crm'],
    with={
        'changelog.mode': 'append',
        'fields.account_number.expression': "ACC#{Number.numberBetween ''1000000'',''1000010''}",
        'fields.amount.expression': "#{Number.numberBetween ''10'',''1000''}",
        'fields.currency.expression': "#{Options.option ''USD'',''EUR'',''INR'',''GBP'',''JPY''}",
        'fields.location.expression': "#{Options.option ''New York'',''Los Angeles'',''Chicago'',''Charlotte'',''San Francisco'',''Indianapolis'',''Seattle'',''Denver'',''Washington'',''Boston'',''El Paso'',''Nashville'',''Detroit'',''Oklahoma City'',''Portland'',''Las Vegas'',''Memphis'',''Louisville'',''Baltimore''}",
        'fields.merchant.expression': "#{Options.option ''Walmart Inc.'', ''Amazon.com Inc.'', ''CVS Health'', ''Costco Wholesale Corporation'', ''Schwarz Group'', ''McKesson Corporation'', ''McDonalds Corporation'', ''Starbucks Corporation'', ''Cencora'', ''The Home Depot Inc.'', ''Yum! Brands'', ''The Kroger Co.'', ''Aldi Group'', ''Walgreens Boots Alliance'', ''Cardinal Health'', ''Subway'', ''JD.com Inc.'', ''Target Corporation'', ''Ahold Delhaize'', ''Lowe Companies Inc.''}",
        'fields.transaction_type.expression': "#{Options.option ''payment'',''payment'', ''payment'' ,''refund'', ''withdrawal''}",
        'fields.status.expression': "#{Options.option ''Successful'',''Successful'', ''Failed'' }",
        'fields.txn_id.expression': '#{IdNumber.valid}',
        'fields.pay_timestamp.expression': "#{date.past ''5'',''SECONDS''}",
        'rows-per-second': '3',
    }
) }}
`txn_id` VARCHAR(36) NOT NULL,
`account_number` VARCHAR(255),
`pay_timestamp` TIMESTAMP_LTZ(3),
`amount` DECIMAL(10, 2),
`currency` VARCHAR(5),
`merchant` VARCHAR(255),
`location` VARCHAR(255),
`status` VARCHAR(255),
`transaction_type` VARCHAR(50),
WATERMARK FOR `pay_timestamp` AS `pay_timestamp` - INTERVAL '5' SECONDS
