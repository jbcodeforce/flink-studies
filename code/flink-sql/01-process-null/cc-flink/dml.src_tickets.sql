insert into src_tickets select
    case_id,
    description,
    priority,
    owner,
    testresults,
     TO_TIMESTAMP_LTZ(creation_ts ,'yyyy-MM-dd HH:mm:ss') as `creation_ts`,
    `$rowtime` as first_ts 
from raw_tickets