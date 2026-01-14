alter table `card-tx.public.transactions` add ( `partition` INT METADATA VIRTUAL);
alter table `card-tx.public.transactions` add ( `offset` BIGINT METADATA VIRTUAL);
alter table `card-tx.public.transactions` SET ('value.format' = 'avro-debezium-registry');
alter table `card-tx.public.transactions` SET ('changelog.mode' = 'append');