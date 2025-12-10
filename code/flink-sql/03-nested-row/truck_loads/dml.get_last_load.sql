 select
      COALESCE(truck_id, 'dummy') as truck_id,
      good_id, max(ts_ms) as ts_ms from truck_loads
    CROSS JOIN UNNEST(truck_loads.loads) as T(c_id, good_id, ts_ms)
    group by truck_id