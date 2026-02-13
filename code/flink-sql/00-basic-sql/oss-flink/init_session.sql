set 'sql-client.execution.result-mode' = 'tableau';
set 'sql-client.execution.runtime-mode' = 'batch';
set 'sql-client.display.color-schema' = 'obsidian';
set 'sql-client.display.show-line-numbers' = 'true';
set 'parallelism.default' = '1';

create catalog j9r_catalog with ( 'type' = 'generic_in_memory');
use catalog j9r_catalog;
create database j9r_db;
use j9r_db;