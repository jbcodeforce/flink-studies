# Agentic applications cross systems

AI agentic applications, at scale will not only be triggered by users, but by **systems** using asynchronous events. It is assumed that AI Agents are becoming experts to certain tasks within a business workflow using domain-specific knowledge, and acts on direct user's queries or from events coming from other systems.
As humen collaborate in a business function and process, AI Agents will collaborate with AI Agents and humen.

As part of the Agentic architecture, there is the planning phase of an agent, which has to use up-to-date data to define the best future actions. As two examples, AI Agents may predict maintenance needs, adjust operational parameters to prevent downtime, and ensure that energy production meets demand without excess waste. In healthcare, AI Agents may analyze genetic data, medical histories, and real-time responses to various treatments.

Flink's event capabilities in real-time distributed event processing, state management and exact-once consistency fault tolerance make it well-suited as a framework for building such system-triggered agents.

Currently, agent frameworks contain some major inhibitors: data preparation and pipeline to build embedding and process semi-structured an unstructured data.

## Needs

* Deliver fresh data from the transactional systems to the AI Agents: stale data leads to irrelevant recommendations and decisions. This is only uses during inference and in the LLM conversation context enrichment.
* Model fine tuning needs clean data that is prepared by Data engineers using traditional SQL query, and python code to build relevant AI features. The data are at rest.
* Search (full text search, vector search and graph search) is used to enrich the LLM context. But point-in-time lookups need to be supported with temporal windows and lookup joins.
* RAG systems that must adapt to information/source changes in real-time.
* Real-time data processing may need scoring computed by AI model, remotly accessed.
* Adopt an event-driven architecture for AI Agents integration and data exchanges using messaging: the orchestration is not hard coded into a work flow (Apache airflow) but more event oriented and AI agent consumers act on those events.
* Event processing can trigger AI agents to act to address customer's inqueries.
* Embeded AI in drones to adapt to environment conditions and task requirements.

???- info "Decision Intelligent Platforms"
    Gartner defines decision intelligence platforms (DIPs) as software to create decision-centric solutions that support, augment and automate decision making of humans or machines, powered by the composition of **data, analytics, knowledge and AI**.

## Challenges

* Not all data is needed in real time, and “real-time” is relative
* **Data** generated isn't delivered to AI systems **fast** enough
* Current Agentic SDK or framework lack replayability and production readiness
* Missing fresh representation of live operational events
* Currently there is a clear separation between data processing and AI inference

## Understanding real-time data needs

One of the key aspects of adopting real-time middleware like Kafka and real-time processing with Flink is to assess what real-time means for each ML features needed for an agent.

Try to assess the following requirements:

* Analytics data needed by end-user process
* Event-driven architectures to automate operational tasks as a response to events, like anomlay detection
* Next best action to take in real-time 
* Assess which business processes need real-time data? What processes could become more proactive?
* what batch processing will perform better with real-time data?
* Does AI Agents need real-time stream to take decision?

## Event-driven AI Agent

Extending the [Agentic reference architecture](https://jbcodeforce.github.io/ML-studies/genAI/agentic/#introduction), introduced by Lilian Weng, which defines how agents should be designed, it is important to leverage the experience acquired during microservice implementations to start adopting an event-driven AI agent architecture, which may be represented by the following high-level figure:

![]()

## Technologies

* Flink paired with Kafka is purpose-built for real-time data processing and event-driven microservices. [Confluent AI with Flink SQL](https://docs.confluent.io/cloud/current/ai/overview.html)
* Agent communication protocols are available to define agent interations: [Agent to Agent from Google](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/) and [ACP from IBM/ Linux foundations](https://agentcommunicationprotocol.dev/introduction/welcome)
* Agent integrate with IT applications and services via [Model Context Protocol from Anthropic](https://www.anthropic.com/news/model-context-protocol)

## Assessment

* What are the current GenAI goals and projects?
* How data are delivered as context to agents?

## [Confluent Cloud Flink SQL constructs](https://docs.confluent.io/cloud/current/flink/reference/functions/model-inference-functions.html#ai-tool-invoke)

A set of function to call an AI or ML model remotely from SQL queries.

