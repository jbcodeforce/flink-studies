insert into raw_error_table
select
    key,
    headers,
    data,
    beforeData
from qlik_cdc_output_table
where (data is null and headers.operation <> 'DELETE') or (data is not null and data.id is null);