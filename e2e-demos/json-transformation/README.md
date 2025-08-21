# Simple Proof Of Concept for Confluent Platform Flink

This is a simple demo to use Confluent Platform with Flink to do a json mapping, a join and an aggregation.

The input is an industrial vehicle rental event. 

## Setup

Be sure to have Confluent Platform deployed on kubernetes ([See this readme](../../deployment/k8s/cp-flink/README.md))

1. Start colima
1. Verify installation and access to Confluent Platform
1. Start SQL Client
