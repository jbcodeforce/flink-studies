-- Smoke query: confirm rows reached perf_sink (run after producer + DML steady state).

SELECT COUNT(*) AS row_count FROM perf_sink;
