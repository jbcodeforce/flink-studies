create table data_exception(
    customer_id string,
    rec_pk_hash string,
    name string,
    rec_create_user_name string,
    rec_update_user_name string,
    email string,
    age int,
    rec_created_ts timestamp_ltz,
    rec_updated_ts timestamp_ltz,
    rec_crud_text string,
    hdr_changeSequence string,
    hdr_timestamp timestamp_ltz,
    tx_ts timestamp_ltz,
    delete_ind int,
    rec_row_hash string,
    primary key(customer_id) not enforced
) distributed by hash(customer_id) into 1 buckets with (
    'changelog.mode' = 'append'
);