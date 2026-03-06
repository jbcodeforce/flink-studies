-- CTAS: create a table with the cutoff trigger row (use as fixture or feed into cutoff_trigger topic via sink).
insert into cutoff_triggers values(
  TIMESTAMP '2025-03-04 11:30:00'
);
