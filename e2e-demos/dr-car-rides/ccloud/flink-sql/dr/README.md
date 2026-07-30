# DR site apply notes
#
# Do not apply DR Flink statements until failover.
# Use a separate Terraform state (see terraform/README.md) so primary
# statements are not destroyed.
#
# Hybrid offset strategy: DML restarts from earliest on mirrored topics
# and rebuilds state. Measure loss with python/assess_loss.py.
