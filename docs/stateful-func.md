# Stateful function

[Stateful Functions](https://ci.apache.org/projects/flink/flink-statefun-docs-release-2.1/) is an open source framework that reduces the complexity of building and orchestrating distributed stateful applications at scale. It brings together the benefits of stream processing with Apache Flink® and Function-as-a-Service (FaaS) to provide a powerful abstraction for the next generation of event-driven architectures.

 ![1](https://ci.apache.org/projects/flink/flink-statefun-docs-release-2.1/fig/concepts/arch_overview.svg)

The Flink worker processes (TaskManagers) receive the events from the ingress systems (Kafka, Kinesis, etc.) and route them to the target functions. They invoke the functions and route the resulting messages to the next respective target functions. Messages designated for egress are written to an egress system 