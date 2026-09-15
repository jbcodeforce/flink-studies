insert into src_tickets select
    case_id,
    description,
    priority,
    owner,
    testresults,
    creation_ts,
    `$rowtime` as first_ts 
from raw_tickets