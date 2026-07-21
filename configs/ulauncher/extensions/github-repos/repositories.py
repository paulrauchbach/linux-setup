import json
import subprocess


def fetch_repositories(owner):
    completed = subprocess.run(
        [
            "gh",
            "repo",
            "list",
            owner,
            "--limit",
            "500",
            "--json",
            "name,url",
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=15,
    )
    return parse_repositories(completed.stdout)


def parse_repositories(payload):
    repositories = json.loads(payload)
    return [{"name": repository["name"], "url": repository["url"]} for repository in repositories]


def fuzzy_score(query, name):
    query = query.casefold().strip()
    name = name.casefold()
    if not query:
        return 0
    if name == query:
        return 10_000
    if name.startswith(query):
        return 5_000 - len(name)
    if query in name:
        return 3_000 - name.index(query) * 10 - len(name)

    cursor = -1
    gap = 0
    for character in query:
        next_cursor = name.find(character, cursor + 1)
        if next_cursor < 0:
            return None
        if cursor >= 0:
            gap += next_cursor - cursor - 1
        cursor = next_cursor
    return 1_000 - gap * 10 - len(name)


def rank_repositories(query, repositories):
    ranked = []
    for repository in repositories:
        score = fuzzy_score(query, repository["name"])
        if score is not None:
            ranked.append((score, repository["name"].casefold(), repository))
    ranked.sort(key=lambda item: (-item[0], item[1]))
    return [repository for _score, _name, repository in ranked]
