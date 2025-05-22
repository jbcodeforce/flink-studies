echo "Be sure to login"

confluent environment use env-
confluent flink region use --cloud aws --region us-west-2
confluent flink endpoint list --context login-jboyer@confluent.io-https://confluent.cloud
confluent flink endpoint use "https://flink-.us-west-2.aws.glb.confluent.cloud"
confluent flink statement list --status running
