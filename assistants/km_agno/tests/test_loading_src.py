from pathlib import Path
import sqlite3
import unittest

from agno.knowledge.reader.markdown_reader import MarkdownReader
from agno.vectordb.search import SearchType
from km_agno.config import get_collection_name, get_vstore_path, get_contents_db_path
from km_agno.content_processor import (
    get_vector_db, 
    get_contents_db,
    get_table_names,
    get_table_column_names,
    get_table_sample,
     list_md_filenames, 
     get_candidate_files,
     get_expert_knowledge
)

current_dir = Path(__file__).resolve().parent
repo_root = current_dir.parent.parent.parent

class TestLoadingSrc(unittest.TestCase):

    def test_getting_md_filenames(self):
        names = list_md_filenames(repo_root)
        assert names
        assert len(names) > 10
        assert all(isinstance(n, Path) and str(n).endswith(".md") for n in names)
        print(names)
       


    def test_loading_one_md(self):
        concept_path = repo_root / "docs" / "concepts" / "index.md"
        assert concept_path.exists()
        vector_db = get_vector_db()
        assert vector_db
        assert vector_db.collection_name == get_collection_name()
        assert vector_db.path == get_vstore_path()
        assert vector_db.persistent_client == True
        assert vector_db.search_type == SearchType.hybrid
        knowledge = get_expert_knowledge()
        knowledge.insert(name="Flink studies repo", 
                        path=concept_path,
                        metadata={"source": "local_file"},
                        skip_if_exists=True,
                        reader=MarkdownReader(),
                        )

    def test_search_knowledge(self):
        knowledge = get_expert_knowledge()
        results = knowledge.search(query="What are the key concepts of Flink?")
        assert results
        assert len(results) > 0
        print(results[0].content)



    def test_contents_db_tables(self):
        table_names = get_table_names()
        assert table_names
        assert "agno_knowledge" in table_names
        print("contents_db tables:", table_names)
        columns = get_table_column_names("agno_knowledge")
        assert columns
        assert "name" in columns
        sample = get_table_sample("agno_knowledge")
        for row in sample:
            print(dict(row))