# [Apache Flink studies, notes and samples](https://jbcodeforce.github.io/flink-studies/)

The vision for this repository is to create a comprehensive, up-to-date, and practical body of knowledge around Apache Flink and its ecosystem, including integration with related technologies (Kafka, Iceberg, CDC, Kubernetes, etc.), accessible as a GitHub Pages site and a set of demonstrations or study code.


Better read in [BOOK format](https://jbcodeforce.github.io/flink-studies/).

## Goals and Repository Organisation

The first goal is to keep notes, best practices, how-to from my deeper dive into Apache Flink. Content may be relevant to others so this is open sourced. All the content is from public documentation. The goal is to present a body of knowledge around Flink ecosystem.

The repository is organized into: 
* **docs**: a living book on Flink subjects
* **code:** Flink programming code in SQL, Python and Java
* **deployment**: for infrastructure as code. For running locally, some of the older code or demos were using Docker compose and desktop, but due to the licensing challenge, and also trying to keep up with k8s deployment, the deployments are going to be local kubernetes, but should be easy to port to any kubernetes cluster hosted by any Cloud provider. For local kubernetes, minicube has some challenges, and colima on mac seems a better experience. I have two laptops one MacOS and on Windows Linux (WSL).

Some end-to-end demos are also implemented to cover integration demonstrations, or more polished demonstrations.

The Implementation-Specific documentation is kept in the respective code folders, via README.md files. The goal is to make it easier to maintain documentation alongside code changes.

### Docs

The docs folder includes:

* Core Flink concepts and architecture
* Flink SQL and Table API deep dives
* Stateful stream processing patterns
* Event time processing and watermarks
* Fault tolerance and exactly-once semantics
* State backends and state management
* Deployment options (standalone, YARN, Kubernetes)
* Performance tuning and monitoring
* Integration guides (Kafka, Iceberg, MySQL CDC)
* End-to-end tutorials and examples
* Troubleshooting and best practices

### Code

* `flink-java` folder includes java main classes to learn about some of the Flink Data streams processing like simple filtering, joins operations, using Quarkus app.
* [flink-sql](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql) is a set of SQL examples
* The e2e-demos includes a set of end to end demonstration with more component. [The e-com-sale-simulator tutorial](https://flink.apache.org/2020/07/28/flink-sql-demo-building-e2e-streaming-application.html) integrates Kafka, MySQL, Elasticsearch, and Kibana with Flink SQL to analyze e-commerce user's behavior in real-time.
* [Flink SQL local java app](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql/flink-sql-quarkus)

### Deployment

* **k8s**: all the local deployment is for colima with kubernetes engine.
* **product-tar**: is for flink and Kafka binary.
* **cc-terraform** is to use terraform to configure Confluent Cloud environment, Kafka Cluster, and Flink compute pools.

## 🙏 Support my work

Love it? Give it a ⭐️ by clicking below:

<a href="https://github.com/jbcodeforce/flink-studies/stargazers"><img src="https://img.shields.io/github/stars/jbcodeforce/flink-studies?style=social" style="margin-left:0;box-shadow:none;border-radius:0;height:24px"></a>