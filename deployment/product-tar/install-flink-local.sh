#VERSION=1.20.1
VERSION=2.1.0
curl https://archive.apache.org/dist/flink/flink-$VERSION/flink-$VERSION-bin-scala_2.12.tgz --output flink-$VERSION.tgz
tar -xzf flink-$VERSION.tgz
rm flink-$VERSION.tgz