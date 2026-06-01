insert into transactions
select
    transaction_id,
    user_id,
    amount,
    ts
from raw_transactions; 