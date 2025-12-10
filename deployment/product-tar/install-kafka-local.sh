
VERSION=4.1.1
BASE_VERSION=2.13
curl https://dlcdn.apache.org/kafka/${VERSION}/kafka_$BASE_VERSION-$VERSION.tgz --output kafka_$BASE_VERSION-$VERSION.tgz
tar -xzf kafka_$BASE_VERSION-$VERSION.tgz
rm kafka_$BASE_VERSION-$VERSION.tgz