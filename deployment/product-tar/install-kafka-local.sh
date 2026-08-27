#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <flink-version>"
    echo "Example: $0 2.1.1"
    exit 1
fi

VERSION=$1
BASE_VERSION=2.13
curl https://dlcdn.apache.org/kafka/${VERSION}/kafka_$BASE_VERSION-$VERSION.tgz --output kafka_$BASE_VERSION-$VERSION.tgz
tar -xzf kafka_$BASE_VERSION-$VERSION.tgz
rm kafka_$BASE_VERSION-$VERSION.tgz