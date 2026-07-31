

---

## 3. Slide-by-Slide Outline & Script Guidelines

### Slide 1: Title & Vision
* **Title:** Leveraging AI for Shift Left Analytics
* **Subtitle:** Moving from Spark Batch Bottlenecks to Real-Time Flink SQL Data Products
* **Key Visual:** Diagram depicting data moving Left (Real-Time Streams + Upstream AI Inference) versus Right (Downstream Batch Warehouses).

### Slide 2: The Downstream Data Crisis
* **Title:** The Multi-Hop Medallion Trap
* **Bullet Points:**
  * Traditional "Shift Right" architectures push cleaning and transformations downstream to warehouses.
  * Result: 24-hour latency, duplicate compute costs, and constant pipeline failure.
  * Upstream source changes silently break downstream analytics dashboards.
* **Takeaway:** We must clean, govern, and enrich data at the event creation layer—**Shifting Left**.

### Slide 3: Real-World Lessons: "Data is Not Software"
* **Title:** Why Naïve AI Agents Fail at Analytics
* **Bullet Points:**
  * *The Insight:* Code generation has instant feedback loops (compilers/tests). Analytics has no simple compiler check for business truth.
  * **Anthropic’s 3 Failures:**
    1. *Concept Ambiguity:* What is an "active order"?
    2. *Data Staleness:* Out-of-date schemas lead to subtle, wrong answers.
    3. *Retrieval Failure:* Agents get lost in enterprise data dumps.
* **Takeaway:** AI agents need strict domain context and structural guardrails to produce accurate insights.

### Slide 4: The Streaming AI Hazard: Flink State & Watermarks
* **Title:** When LLMs Write SQL for Apache Flink
* **Bullet Points:**
  * LLMs default to unbounded ANSI/Batch SQL logic.
  * **Unbounded Joins:** Missing State TTL (`table.exec.state.ttl`) causes RocksDB memory leaks and node crashes.
  * **Watermark Blindness:** Omitting event-time definitions turns deterministic stream aggregation into random guesses.
* **Takeaway:** Streaming AI requires specialized Flink prompts, schema context, and automated CI linters.

### Slide 5: Accelerating Migration: Spark Batch to Real-Time Flink
* **Title:** AI-Driven Migration: Spark to Flink SQL
* **Bullet Points:**
  * *Why Dumping Query Logs Fails:* Feeding thousands of raw historical queries to an LLM yields <1% accuracy gain.
  * *The Solution:* Structured AI Skills (referencing `jbcodeforce/migration-to-flink-skills`).
  * Automated AST translation of PySpark windowing to Flink `CUMULATE` / `HOP` functions.
  * Automated conversion of batch logic to stateful Temporal Table Joins.

### Slide 6: The Modern Shift-Left Streaming Architecture
* **Title:** Real-Time Data Products with Confluent Cloud & Flink
* **Bullet Points:**
  * **Data Contracts & Schema Registry:** Protect topic schemas upstream at the point of origin.
  * **Continuous Flink Processing:** Low-latency stream transformations replace periodic Spark runs.
  * **Confluent Tableflow:** Stream once -> Serve real-time microservices via Flink SQL + automatically materialize Apache Iceberg tables for downstream analytics.

### Slide 7: Confluent Intelligence & Inline AI Inference
* **Title:** Bringing AI into the Stream (FLIP-437)
* **Bullet Points:**
  * AI is not just writing queries; it is executing *inside* the streaming engine.
  * Real-time inference using `CREATE MODEL` and `ML_EVALUATE` in Flink SQL.
  * Enrich live event streams with fraud scoring, sentiment analysis, or embedding vectors before reaching the lakehouse.

### Slide 8: Data as a Product (DaaP) Foundations
* **Title:** Building Governed Streaming Data Products
* **Bullet Points:**
  * **Canonical Streams:** Curating single source-of-truth Kafka topics instead of dozens of duplicated raw streams.
  * **Metadata as Code:** Column docs, stream ownership, and event SLAs maintained alongside Flink code.
  * Interoperable outputs for operational apps, data science teams, and BI toolsets.

### Slide 9: Knowledge Management for the Streaming CoE
* **Title:** Building a High-Accuracy Agentic Stack
* **Bullet Points:**
  * **Colocated Git Repositories:** Flink SQL, Data Contracts, and AI skills stored together and enforced via CI/CD.
  * **Semantic Layer Routing:** Force AI agents to query pre-built Flink metrics before touching raw topics.
  * **Context Injection:** Piping domain knowledge graphs and business definitions into AI context windows.
  * *Anthropic Validation:* Achieving **95% query automation with ~95% aggregate accuracy**.

### Slide 10: The Evolution of the Data Engineer (2026)
* **Title:** Day-in-the-Life: Data Engineer in 2026
* **Comparison Matrix:**
  * *From:* Tuning Spark JVM flags, writing boilerplate ETL, fixing midnight pipeline failures.
  * *To:* Designing streaming Data Contracts, curating AI Agent Skills, orchestrating real-time Flink topologies on Confluent Cloud.

### Slide 11: ROI & Business Impact
* **Title:** Measurable Business Outcomes
* **Bullet Points:**
  * **Data Latency:** Reduced from hours/days to milliseconds.
  * **Infrastructure Savings:** Eliminating redundant batch ETL runs and duplicated warehouse tables.
  * **Developer Velocity:** 5x faster migration from legacy Spark batch to modern Flink streaming via curated AI skills.
  * **Accuracy:** High confidence in AI self-service queries through governed data foundations.

### Slide 12: Key Takeaways & Action Plan
* **Title:** Next Steps for the Streaming Enterprise
* **Bullet Points:**
  * 1. **Shift Left:** Clean and govern data at the event boundary with Confluent Data Contracts.
  * 2. **Codify Expertise:** Use curated AI skills (`migration-to-flink-skills`) instead of raw query dumps.
  * 3. **Empower the CoE:** Build strong data foundations to achieve 95%+ AI accuracy.
  * **Resource Link:** `https://github.com/jbcodeforce/migration-to-flink-skills/`