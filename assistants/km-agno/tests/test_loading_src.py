from pathlib import Path
import unittest


from km_agno.content_processor import get_candidate_files, list_md_filenames

current_dir = Path(__file__).resolve().parent
repo_root = current_dir.parent.parent.parent

class TestLoadingSrc(unittest.TestCase):

    def test_getting_md_filenames(self):
        names = list_md_filenames(repo_root)
        assert names
        assert len(names) > 0
        assert all(isinstance(n, Path) and str(n).endswith(".md") for n in names)
        assert names == get_candidate_files(repo_root)
       