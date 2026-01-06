#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <flink-version>"
    echo "Example: $0 2.1.1"
    exit 1
fi

VERSION=$1
SCALA_VERSION=2.12

curl https://archive.apache.org/dist/flink/flink-$VERSION/flink-$VERSION-bin-scala_$SCALA_VERSION.tgz --output flink-$VERSION.tgz
tar -xzf flink-$VERSION.tgz
rm flink-$VERSION.tgz
export FLINK_HOME=$(pwd)/flink-$VERSION
cp $FLINK_HOME/opt/flink-python-1.20.3.jar $FLINK_HOME/lib/