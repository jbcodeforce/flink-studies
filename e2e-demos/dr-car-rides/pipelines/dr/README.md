# DR Site Flink SQL Deployment Notes

In active/passive mode, DR Flink statements are deployed during failover:

```bash
# Deploy to DR compute pool
make deploy SITE=dr

# Or undeploy DR statements when tearing down or failing back:
make undeploy SITE=dr
```

- **Offset Strategy**: When Flink starts on DR, DML reads from the mirrored `rides_raw` topic (earliest offset) to rebuild pipeline state. `rides_clean` and `driver_stats` are not mirrored: the DR deploy creates their topics and schemas (the DR registry is `READWRITE` by then).
- **Loss Assessment**: Use `python/assess_loss.py` to evaluate sequence gaps and RPO between primary producer logs and DR topic mirrors.
