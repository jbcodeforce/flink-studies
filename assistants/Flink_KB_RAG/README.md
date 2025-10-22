# Flink Assistant

This is a RAG based solution to support Flink Q&A.

## Approach

The RAG techniques used are

* Routing with query classification
* Semantic search with document indexing

## Build the knowledge corpus

The goal is to have a tool to chunk a set of URLs source per domain of knowledge. We want Flink SQL, Table API, Flink general product knowledge, and Flink on Kubernetes specific.

All those domains are collections in Vector Store. Use Chromadb as vector store.

## LLM local using Ollama

Use [ollama docker image](https://hub.docker.com/r/ollama/ollama):

```sh
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```

* install `docker exec -it ollama bash` then `ollama pull qwen2.5:14b`
* Serve the model for inference: `ollama run qwen2.5:14b`

##

