


Keeping business state in sync, everywhere, at the same time.

I just published a Customer 360 demo built on the Streamhouse architecture with Confluent Cloud. The problem it addresses: how do you make sure no team, applications, or AI agents are working off a stale or conflicting copy of business facts?

The demo walks through an end-to-end streaming pipeline:

- Capture – Debezium CDC from PostgreSQL into Kafka
- Transport – Kafka topics with contracts governed by Schema Registry
- Transform – Confluent Cloud for Flink building golden records and customer 360 metrics (organized with a star schema, deployed via dbt Confluent)
- Serve – Tableflow writing Iceberg tables to object storage, plus a real-time context engine and snapshot queries to feed apps and AI agents

It's organized around three real personas — SRE, Data Engineer, and Application Developer — with both Terraform and Console paths, a local-run option, and a web app to drive the scenario live. It demonstrates how we can drive data streaming processing end-to-end down to the business intelligence dashboard or decision automation with AI systems: generative AI or Symbolic AI.

If you're exploring streamhouse / lakehouse patterns on Confluent, take a look:
https://github.com/jbcodeforce/streamhouse_c360_demo and the scenario script:  to read what can be done

Thank a lot to Confluent Data Streaming Processing Ninja team, and Zander Matheson for their support, feedbacks and recommendations.