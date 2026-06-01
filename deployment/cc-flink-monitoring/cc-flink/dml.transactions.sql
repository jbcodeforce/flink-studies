insert into transactions
select
    t.transaction_id,
    t.user_id,
    u.full_name,
    u.email,
    t.amount,
    t.ts
from raw_transactions t
LEFT JOIN users u ON t.user_id = u.user_id;
