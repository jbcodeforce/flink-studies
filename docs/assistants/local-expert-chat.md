---
title: "Local expert chat (Agno)"
source: flink-studies/docs/assistants/local-expert-chat.md
ingested:
tags: [flink, assistants]
type: article
compiled: false
---
# Local expert chat (Agno)

This site is built with MkDocs and deployed to GitHub Pages. The **indexed Flink expert chat** is a separate application that runs **only on your machine**. It is not part of the static site and is not available on the published documentation URL.

!!! warning "GitHub Pages"

    Links like `[http://localhost:5174]()` work only when you have started the chat stack locally. Visitors browsing the published docs see this page as setup instructions, not a live chat.

## What it does

The [km-agent](https://github.com/jbcodeforce/km-agent) assistant indexes markdown and code under any studies repository (see the README there for scope), stores embeddings locally, and exposes an **AgentOS** HTTP API plus a **Vue** UI for semantic Q&A over your content.

## Quick start (three URLs)

After indexing and starting the stack you get:

| Service | URL | Purpose |
|--------|-----|---------|
| MkDocs | [http://localhost:8003](http://localhost:8003) | This documentation (when using `start_local.sh`) |
| Expert chat UI | [http://localhost:5174](http://localhost:5174) | Browser chat against AgentOS |

Use the nav entry **Assistants → Local expert chat** while running MkDocs locally to jump back here; open **Expert chat UI** in another tab when the frontend is running.
