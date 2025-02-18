
IMAGE_NAME=jbcodeforce/ecom-flink-app:1-19.1-cp1
APP_NAME=ecom-flink-app
ENV_NAME=env1

build: package image create_flink_app

package:
	@cd flink-app; mvn clean package -DskipTest=true

image:
	@cd flink-app; docker build -t $(IMAGE_NAME) .

port-forward:
	@kubectl port-forward svc/cmf-service 8080:80 -n flink

create_flink_app:
	@confluent flink application create k8s/cmf_app_deployment.yaml  --environment $(ENV_NAME) --url http://localhost:8080 

delete_flink_app:
	@confluent flink application delete $(APP_NAME) --environment $(ENV_NAME) --url http://localhost:8080 

access_flink_ui:
	@confluent flink application web-ui-forward $(APP_NAME) --environment $(ENV_NAME) --port 8090 --url http://localhost:8080