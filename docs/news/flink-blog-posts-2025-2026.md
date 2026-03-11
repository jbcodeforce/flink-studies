# Apache Flink Blog Posts Summary (2025–2026)

Summary of posts from the [Apache Flink Blog](https://flink.apache.org/posts/) for 2025 and 2026.

---

## 2026

### Apache Flink Kubernetes Operator 1.14.0 Release Announcement
**February 15, 2026** — Sergio Chong Loo / Daniel Rossos

- First major 2026 release of the Flink Kubernetes Operator.
- **Highlight:** Native **Blue/Green deployment** support for production.
- Enables deploying stateful streaming applications without downtime via automated Blue/Green deployments on Kubernetes.
- [Continue reading →](https://flink.apache.org/2026/02/15/apache-flink-kubernetes-operator-1.14.0-release-announcement/)

---

### Apache Flink Agents 0.2.0 Release Announcement
**February 6, 2026** — Xintong Song

- Second release of the Flink Agents sub-project.
- **Preview version:** APIs and config may change; some known/unknown issues possible (tracked on GitHub Issues).
- Download and documentation/quickstart are available.
- [Continue reading →](https://flink.apache.org/2026/02/06/apache-flink-agents-0.2.0-release-announcement/)

---

### Flink Community Update - February '26
**February 1, 2026** — David Radley

- Monthly community recap returns (first since August 2020).
- Covers January 2026: Flink-related blogs, Dev List summary, key themes, community announcements (new committers, new PMC member), FLIP activity (accepted vs. in discussion), and the Kubernetes Operator 1.14.0 release.
- [Continue reading →](https://flink.apache.org/2026/02/01/flink-community-update-february26/)

---

## 2025

### Apache Flink Agents 0.1.1 Release Announcement
**December 9, 2025** — Wenjin Xie

- First maintenance release of the Flink-Agents 0.1 series.
- Includes 11 bug fixes, security fixes, and small improvements (excluding build-only changes).
- Upgrade recommended; full change list in ISSUE.
- [Continue reading →](https://flink.apache.org/2025/12/09/apache-flink-agents-0.1.1-release-announcement/)

---

### Apache Flink 2.2.0: Advancing Real-Time Data + AI
**December 4, 2025** — Hang Ruan

- Major release focusing on **real-time data + AI** and stream processing for the “AI era.”
- **73 contributors**, **9 FLIPs** implemented, **220+ issues** resolved.
- **New/improved:** AI capabilities, materialized tables, Connector framework, batch processing, PyFlink.
- **Notable features:** **ML_PREDICT** (LLM inference), **VECTOR_SEARCH** (real-time vector similarity search) for streaming AI apps.
- [Continue reading →](https://flink.apache.org/2025/12/04/apache-flink-2.2.0-advancing-real-time-data--ai-and-empowering-stream-processing-for-the-ai-era/)

---

### From Stream to Lakehouse: Kafka Ingestion with the Flink Dynamic Iceberg Sink
**November 11, 2025** — Swapna Marru

- Describes the **Flink Dynamic Iceberg Sink** pattern for ingesting many evolving Kafka topics into a lakehouse.
- Addresses complex, brittle pipelines and manual changes when write patterns evolve.
- **Capabilities:** Write streaming data into multiple Iceberg tables dynamically, with schema evolution and zero-downtime adaptation; create and write to new tables based on instructions in the records.
- [Continue reading →](https://flink.apache.org/2025/11/11/from-stream-to-lakehouse-kafka-ingestion-with-the-flink-dynamic-iceberg-sink/)

---

### Apache Flink 2.0.1 Release Announcement
**November 10, 2025** — Zakelly Lan

- First bugfix release of the Flink 2.0 line.
- **51** bug fixes, security fixes, and minor improvements (excluding build-only).
- Upgrade recommended; full list in JIRA.
- [Continue reading →](https://flink.apache.org/2025/11/10/apache-flink-2.0.1-release-announcement/)

---

### Apache Flink 2.1.1 Release Announcement
**November 10, 2025** — Gabor Somogyi

- First bugfix release of the Flink 2.1 line.
- **25** bug fixes, security fixes, and minor improvements (excluding build-only).
- Upgrade to 2.1.1 or higher recommended; full list in JIRA.
- [Continue reading →](https://flink.apache.org/2025/11/10/apache-flink-2.1.1-release-announcement/)

---

### Apache Flink Agents 0.1.0 Release Announcement
**October 15, 2025** — Xintong Song

- **First preview** of **Apache Flink Agents** (0.1.0), a new sub-project.
- **Flink Agents:** event-driven AI agents on Flink’s streaming runtime.
- Combines Flink (scale, low latency, fault tolerance, state) with agent features (LLMs, tools, memory, dynamic orchestration).
- [Continue reading →](https://flink.apache.org/2025/10/15/apache-flink-agents-0.1.0-release-announcement/)

---

### From Stream to Lakehouse: Kafka Ingestion with the Flink Dynamic Iceberg Sink
**October 14, 2025** — Swapna Marru

- Same theme as the November 11 post: **Flink Dynamic Iceberg Sink** for Kafka → lakehouse ingestion with dynamic, schema-evolving writes and zero-downtime adaptation.
- [Continue reading →](https://flink.apache.org/2025/10/14/from-stream-to-lakehouse-kafka-ingestion-with-the-flink-dynamic-iceberg-sink/)

---

## Quick reference

| Date       | Topic |
|-----------|--------|
| Feb 15, 2026 | Kubernetes Operator 1.14.0 — Blue/Green deployments |
| Feb 6, 2026  | Flink Agents 0.2.0 |
| Feb 1, 2026  | Community update Feb '26 |
| Dec 9, 2025  | Flink Agents 0.1.1 (bugfixes) |
| Dec 4, 2025  | Flink 2.2.0 — Real-time Data + AI, ML_PREDICT, VECTOR_SEARCH |
| Nov 11, 2025 | Dynamic Iceberg Sink (Kafka → lakehouse) |
| Nov 10, 2025 | Flink 2.0.1 and 2.1.1 (bugfixes) |
| Oct 15, 2025 | Flink Agents 0.1.0 (first preview) |
| Oct 14, 2025 | Dynamic Iceberg Sink (Kafka → lakehouse) |
