cd $(dirname $0)
 
docker run -ti --rm -p 9000:9000 \
     -v $(pwd)/:/home \
    -e KAFKA_BROKERCONNECT=$KAFKA_BOOTSTRAP_SERVERS \
    -e KAFKA_PROPERTIES=$(cat kafka.properties | base64) \
    -e JVM_OPTS="-Xms32M -Xmx64M" \
    -e SERVER_SERVLET_CONTEXTPATH="/" \
    obsidiandynamics/kafdrop
