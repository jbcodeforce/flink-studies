echo "######################"
echo "Start console consumer to see some messages"

docker exec -ti kafka bash -c "/opt/kafka/bin//kafka-console-consumer.sh --topic user_behavior --bootstrap-server localhost:9092 --from-beginning --max-messages 10"
