# Compute ETA: deploy Flink statements via Confluent CLI.
# Set ENV_ID, COMPUTE_POOL_ID (or CPOOLID), DB_NAME, CC_CONTEXT (or CCLOUD_* variants).
# See README.md for prerequisites and env vars.

.PHONY: deploy deploy-confluent-cloud undeploy undeploy-confluent-cloud

deploy:
	python deploy_flink_statements.py deploy

deploy-confluent-cloud:
	python deploy_flink_statements.py deploy --confluent-cloud

undeploy:
	python deploy_flink_statements.py undeploy

undeploy-confluent-cloud:
	python deploy_flink_statements.py undeploy --confluent-cloud
