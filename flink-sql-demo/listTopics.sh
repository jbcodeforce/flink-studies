echo "######################"
echo " List Topics"

docker exec -ti kafka bash -c "/opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list"
