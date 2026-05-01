import asyncio
from pathlib import Path

from agno.agent import Agent
from agno.knowledge.reader.markdown_reader import MarkdownReader

from agno.os import AgentOS

from km_agno.content_processor import get_expert_knowledge, get_contents_db, get_expert_agent
from km_agno.config import load_assistants_dotenv, get_llm_model

current_dir = Path(__file__).resolve().parent
repo_root = current_dir.parent.parent.parent

load_assistants_dotenv()

# One SqliteDb for knowledge rows and agent sessions — AgentOS session APIs need os.dbs non-empty.
_contents_db = get_contents_db()
knowledge = get_expert_knowledge(contents_db=_contents_db)

async def insert_knowledge():
    concept_path = repo_root / "docs" / "concepts" / "index.md"
    await knowledge.ainsert(name="Flink studies repo", 
                       path=concept_path,
                       metadata={"source": "local_file"},
                       skip_if_exists=True,
                       reader=MarkdownReader(),
                       )
expert_agent = get_expert_agent()

agent_os = AgentOS(
    agents=[expert_agent],
)

app = agent_os.get_app()

if __name__ == "__main__":
    asyncio.run(insert_knowledge())
    # Import string must be "package.module:attr" for reload (same pattern as agno cookbook basic:app).
    agent_os.serve(app="km_agno.server:app", reload=True)
