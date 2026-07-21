import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
EXTENSION_ROOT = REPO_ROOT / "configs" / "ulauncher" / "extensions" / "github-repos"
sys.path.insert(0, str(EXTENSION_ROOT))

from repositories import parse_repositories, rank_repositories  # noqa: E402


class GitHubRepositoriesTest(unittest.TestCase):
    def setUp(self):
        self.repositories = [
            {"name": "linux-setup", "url": "https://github.com/paulrauchbach/linux-setup"},
            {"name": "aktenwerk", "url": "https://github.com/paulrauchbach/aktenwerk"},
            {"name": "brave-tab-search", "url": "https://github.com/paulrauchbach/brave-tab-search"},
        ]

    def test_parses_all_returned_repositories(self):
        payload = json.dumps(self.repositories)
        self.assertEqual(parse_repositories(payload), self.repositories)

    def test_exact_match_ranks_first(self):
        ranked = rank_repositories("aktenwerk", self.repositories)
        self.assertEqual(ranked[0]["name"], "aktenwerk")

    def test_prefix_and_fuzzy_matches(self):
        self.assertEqual(rank_repositories("lin", self.repositories)[0]["name"], "linux-setup")
        self.assertEqual(rank_repositories("bts", self.repositories)[0]["name"], "brave-tab-search")

    def test_nonexistent_repository_is_not_suggested(self):
        self.assertEqual(rank_repositories("definitely-missing", self.repositories), [])


if __name__ == "__main__":
    unittest.main()
