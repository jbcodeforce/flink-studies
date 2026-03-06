-- Build dimension from silver src_accounts (one row per account, latest state).
INSERT INTO dim_account
SELECT
    account_id,
    account_name,
    region,
    created_at,
    src_op,
    is_deleted,
    src_timestamp
FROM src_accounts;
