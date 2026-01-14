alter table `card-tx.public.customers` add ( `partition` INT METADATA VIRTUAL);
alter table `card-tx.public.customers` add ( `offset` INT METADATA VIRTUAL);