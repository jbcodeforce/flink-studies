---
name: document-app
description: Guidelines and instructions for generating and updating documentation for this repository.
---

# Application Documentation Guidelines

The agent should use these instructions to generate accurate and consistent documentation for this Apache Flink best practices project.

## Conventions
*   **Headings:** Use sentence case for all headings.
*   **Readmes:** Every ./code subfolder or /e2e-demo should have a `README.md` with a "Quick Start" section.
*   **Code Examples:** Code examples must be complete and runnable.

## Project Context
*   **Technology Stack:** This project uses Java, Python, Terraform and bash.

### `/docs` - Documentation (MkDocs Configuration)
- **Purpose**: Contains all documentation files configured for MkDocs static site generation
- **Agent Role**: 
  - Maintain and update documentation structure
  - Ensure proper MkDocs YAML configuration
  - Keep documentation current with code examples
  - Manage cross-references and navigation structure

### `/code` - Implementation Examples
#### `/code/flink-sql` - SQL Examples and Tutorials
- Simple how-to guides for Flink SQL operations
- Basic SQL patterns and common use cases
- Data transformation examples

#### `/code/flink-java` - Java DataStream API Examples  
- Java-based Flink applications
- DataStream API demonstrations
- Batch and stream processing samples

#### `/code/table-api` - Table API Examples
- Table API implementations in Java and Python
- Bridge between SQL and programmatic APIs

#### `/code/tools` - Utility Scripts
- Helper scripts for data processing and analysis

### `/deployment` - Deployment Configurations
- **Purpose**: Contains various deployment strategies and configurations
- **Agent Role**:
  - Maintain deployment scripts for different environments
  - Keep Docker, Kubernetes, and Terraform configurations updated
  - Ensure deployment examples work with latest Flink versions
  - Document deployment best practices

#### Key Deployment Types:
- **Docker**: Local development and testing environments
- **Kubernetes**: Production-ready K8s deployments with operators
- **Confluent Cloud**: Cloud-native Flink deployments
- **Custom Images**: Specialized Flink runtime configurations

### `/e2e-demos` - End-to-End Customer Demonstrations
- **Purpose**: Advanced, customer-facing demonstrations solving real business problems
- **Agent Role**:
  - Maintain production-ready demo scenarios
  - Ensure demos work across different deployment environments
  - Keep demos updated with latest Flink and Kafka versions
  - Document business use cases and technical implementation

## Prohibited Actions
*   Do not modify existing documentation without user approval when in agent mode.
*   Do not delete files in the `/docs` directory.

## Best Practices
*   **Start with an outline** and drill down into each section.
*   **Add the "why"** that is not immediately obvious from the implementation code.
*   **Generate Mermaid diagrams** for complex flows to improve readability.
* Do not use words in bold in the middle of sentence, it sounds to AI generated.