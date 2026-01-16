-- By default the changelog mode is retract.
-- it is therefore not possible to use partition and offset. If they are needed then
-- change the changelog mode to append.
-- alter table `card-tx.public.customers` add ( `partition` INT METADATA VIRTUAL);
-- alter table `card-tx.public.customers` add ( `offset` INT METADATA VIRTUAL);
-- alter table `card-tx.public.transactions` SET ('changelog.mode' = 'append');
alter table `card-tx.public.customers` SET ('value.format' = 'avro-registry');
