# [Apache Flink studies, notes and samples](https://jbcodeforce.github.io/flink-studies/)

The vision for this repository is to create a comprehensive, up-to-date, and practical body of knowledge around Apache Flink and its ecosystem, including integration with related technologies (Kafka, Iceberg, CDC, Kubernetes, etc.), accessible as a GitHub Pages site.


Better read in [BOOK format](https://jbcodeforce.github.io/flink-studies/).

## Goals and Repository Organisation

The vision for this repository is to create a comprehensive, up-to-date, and practical body of knowledge around Apache Flink and its ecosystem, including integration with related technologies (Kafka, Iceberg, CDC, Kubernetes, etc.), accessible as a GitHub Pages site.

The first goal is to keep notes, best practices, how-to from my deeper dive into Apache Flink. Content may be relevant to other  so this is open sourced. All the content is from public documentation. The goal is to be a body of knowledge around Flink ecosystem.

The repository is organized in docs, Flink programming code in SQL, Python and Java, and deployment for infrastructure as code. For running locally, some of the older code or demos were using Docker compose and desktop, but due to the licensing challenge, and also trying to keep up with k8s deployment, the deployments are going to be local kubernetes, but should be easy to port to Cloud provider k8s services. For local kubernetes, minicube has some challenges, and colima on mac seems a better experience. I have two laptops one MacOS and on Windows Linux (WSL).

Some end-to-end demos are also implemented to cover integration demonstrations.

The Implementation-Specific documentation is kept in the respective code folders with their implementations, to make it easier to maintain documentation alongside code changes.

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

## Roadmap

### Phase 1: Foundation & Structure

* [] Organize documentation and code samples by topic and technology.
* [] Ensure all existing content is up-to-date and well-formatted.
* [x] Set up automated publishing to GitHub Pages.

### Phase 2: Core Flink Concepts

* Deep dives into Flink architecture, APIs (DataStream, Table, SQL), and deployment models.
* Best practices, common pitfalls, and performance tuning.

### Phase 3: Integrations & Ecosystem

* Tutorials and demos integrating Flink with Kafka, Iceberg, MySQL, Elasticsearch, etc.
* End-to-end use cases (e.g., e-commerce analytics, real-time monitoring).

### Phase 4: Advanced Topics

* Stateful Functions, CEP, Flink on Kubernetes, Flink with Terraform.
* Monitoring, scaling, and productionizing Flink applications.

### Phase 5: Community & Contribution

*Guidelines for contributions, issue templates, and PR process.
* Regular content updates and community Q&A.

## Milestones

* [ ] Initial content audit and reorganization
* [ ] Core Flink documentation complete
* [ ] At least 3 end-to-end integration demos
* [ ] Advanced topics section launched
* [ ] Community contribution guidelines published

## Content tracking

| Folder | Docs | Status | 
| --- | --- | --- |
| docs | index | Main page = validated 11/2024 |
| architecture | index | |
|  | fitforpurpose | |
|  | cookbook | to work on |
|  | flink-sql | |
|  | Kafka | |
| coding | first app | |
|  | cep | |
|  | flink-sql | |
|  | getting-started | |
|  | k8s-deploy | |
|  | programming | |
|  | Table API | |
|  | Stateful Function | |
|  | Terraform | |
| Techno | confluent cloud flink | |
|  | confluent platform flink | |
| | Flink k8s monitoring | | 

## 🙏 Support my work

Love it? Give it a ⭐️ by clicking below:

<a href="https://github.com/jbcodeforce/flink-studies/stargazers"><img src="https://img.shields.io/github/stars/jbcodeforce/flink-studies?style=social" style="margin-left:0;box-shadow:none;border-radius:0;height:24px"></a>