# DR Site Flink SQL Deployment Notes

In active/passive mode, DR Flink statements are deployed during failover:

```bash
# Deploy to DR compute pool
make deploy SITE=dr

# Or undeploy DR statements when tearing down or failing back:
make undeploy SITE=dr
```

- **Offset Strategy**: When Flink starts on DR, DML reads from the mirrored `rides_raw` topic to rebuild pipeline state and populate `rides_clean` and `driver_stats`.
- **Loss Assessment**: Use `python/assess_loss.py` to evaluate sequence gaps and RPO between primary producer logs and DR topic mirrors.
