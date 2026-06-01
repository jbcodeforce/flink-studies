"""
A Flink Researcher Agent that can search the web for information and save it to a knowledge base.

The agent can search the web for information and save it to a knowledge base.
Run on compatible models with OpenAI API. Like local ollama.
It support HILP, human-in-the-loop, to validate saving to knowledge base.
Usage:
```sh
uv run flink_researcher.py
```

Example:
```sh
uv run flink_researcher.py "What is Apache Flink?"
```

Useful links
- https://docs.agno.com/tools/toolkits/search/websearch

"""
from datetime import datetime, timezone
import json
from rich.console import Console
from rich.prompt import Prompt

from agno.agent import Agent
from agno.db.sqlite import SqliteDb
from agno.knowledge import Knowledge
from agno.knowledge.embedder.ollama import OllamaEmbedder
from agno.knowledge.reader.text_reader import TextReader
from agno.models.openai.like import OpenAILike
from agno.tools import tool
from agno.tools.websearch import WebSearchTools
from agno.utils import pprint
from agno.vectordb.chroma import ChromaDb
from agno.vectordb.search import SearchType


DEFAULT_LLM_BASE_URL = "http://127.0.0.1:11434/v1"
DEFAULT_OLLAMA_HOST = "http://127.0.0.1:11434"
DEFAULT_LLM_MODEL = "hermes3:latest"
DEFAULT_EMBEDDER_MODEL = "nomic-embed-text:latest"
DEFAULT_EMBEDDER_DIMENSIONS = 768
DEFAULT_LLM_TEMPERATURE = 0.4
DEFAULT_LLM_API_KEY = "localkey"

agent_db = SqliteDb(db_file="data/flink_researcher.db")

# ---------------------------------------------------------------------------
# Knowledge Base for Learnings
# ---------------------------------------------------------------------------
learnings_kb = Knowledge(
    name="Agent Learnings",
    vector_db=ChromaDb(
        name="learnings",
        collection="learnings",
        path="data/chromadb",
        persistent_client=True,
        search_type=SearchType.hybrid,
        hybrid_rrf_k=60,
        embedder=OllamaEmbedder(
            id=DEFAULT_EMBEDDER_MODEL,
            dimensions=DEFAULT_EMBEDDER_DIMENSIONS,
            host=DEFAULT_OLLAMA_HOST,
        ),
    ),
    max_results=5,
    contents_db=agent_db,
)


# ---------------------------------------------------------------------------
# Custom Tool: Save Learning (requires confirmation)
# ---------------------------------------------------------------------------
@tool(requires_confirmation=True)
def save_learning(title: str, learning: str) -> str:
    """
    Save a reusable insight to the knowledge base for future reference.
    This action requires user confirmation before executing.

    Args:
        title: Short descriptive title (e.g., "Flink checkpoint interval tuning")
        learning: The insight to save — be specific and actionable

    Returns:
        Confirmation message
    """
    # Validate inputs
    if not title or not title.strip():
        return "Cannot save: title is required"
    if not learning or not learning.strip():
        return "Cannot save: learning content is required"

    # Build the payload
    payload = {
        "title": title.strip(),
        "learning": learning.strip(),
        "saved_at": datetime.now(timezone.utc).isoformat(),
    }

    # Save to knowledge base
    learnings_kb.insert(
        name=payload["title"],
        text_content=json.dumps(payload, ensure_ascii=False),
        reader=TextReader(),
        skip_if_exists=True,
    )

    return f"Saved: '{title}'"

instructions = """
You are a data streaming agent, expert in Apache Flink.

You have two special abilities:
1. Search your knowledge base for previously saved learnings
2. Save new insights using the save_learning tool

## Workflow

1. Check Knowledge First
   - Before answering, search for relevant prior learnings
   - Apply any relevant insights to your response

2. Gather Information
   - Use WebSearchTools tools to access the web for information
   - Combine with your knowledge base insights

3. Save Valuable Insights
   - If you discover something reusable, save it with save_learning
   - The user will be asked to confirm before it's saved
   - Good learnings are specific, actionable, and generalizable

## What Makes a Good Learning

- Specific: "Tech P/E ratios typically range 20-35x" not "P/E varies"
- Actionable: Can be applied to future questions
- Reusable: Useful beyond this one conversation

Don't save: Raw data, one-off facts, or obvious information.\
"""

agent = Agent(
    name="Flink Researcher",
    description="A research agent that can help you find information about Flink.",
    model=OpenAILike(id=DEFAULT_LLM_MODEL, base_url=DEFAULT_LLM_BASE_URL, temperature=DEFAULT_LLM_TEMPERATURE, api_key=DEFAULT_LLM_API_KEY),
    instructions=instructions,
    tools=[
        WebSearchTools(backend="google",
                        fixed_max_results=3,
                        timeout=10,
                        region="us-en"),
        save_learning,
    ],
    knowledge=learnings_kb,
    search_knowledge=True,
    db=agent_db,
    add_datetime_to_context=True,
    add_history_to_context=True,
    num_history_runs=5,
    markdown=True,
)



# ---------------------------------------------------------------------------
# Run the Agent
# ---------------------------------------------------------------------------
def _print_response(run_response) -> None:
    if run_response.content:
        pprint.pprint_run_response(run_response, markdown=True)


def _handle_confirmations(run_response, console: Console):
    if not run_response.active_requirements:
        return run_response

    for requirement in run_response.active_requirements:
        if requirement.needs_confirmation:
            console.print(
                f"\n[bold yellow]Confirmation Required[/bold yellow]\n"
                f"Tool: [bold blue]{requirement.tool_execution.tool_name}[/bold blue]\n"
                f"Args: {requirement.tool_execution.tool_args}"
            )
            choice = (
                Prompt.ask(
                    "Save this learning?",
                    choices=["y", "n"],
                    default="n",
                )
                .strip()
                .lower()
            )
            if choice == "n":
                requirement.reject()
                console.print("[red]Rejected[/red]")
            else:
                requirement.confirm()
                console.print("[green]Approved[/green]")

    return agent.continue_run(
        run_id=run_response.run_id,
        requirements=run_response.requirements,
    )


if __name__ == "__main__":
    console = Console()
    console.print("Ask about Apache Flink. Type 'bye' to exit.")
    done = False
    while not done:
        question = Prompt.ask("Question >", default="")
        if not question or "bye" in question:
            done = True
        else:
            run_response = agent.run(question)
            _print_response(run_response)
            if run_response.active_requirements:
                run_response = _handle_confirmations(run_response, console)
                _print_response(run_response) 