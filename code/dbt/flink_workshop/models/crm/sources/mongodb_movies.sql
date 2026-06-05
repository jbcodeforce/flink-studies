{{ config(
    materialized='streaming_source',
    connector='mongodb',
    enabled=var('crm_enable_mongodb', false),
    statement_name='fw_crm_mongodb_movies',
    tags=['crm'],
    pre_hook=['{{ crm_create_mongodb_connection() }}'],
    with={
        'mongodb.connection': 'mongodb_connection',
        'mongodb.database': 'sample_mflix',
        'mongodb.collection': 'movies',
        'mongodb.index': 'default',
    },
) }}
title string,
genres array<string>,
rated string,
plot string,
`year` int
