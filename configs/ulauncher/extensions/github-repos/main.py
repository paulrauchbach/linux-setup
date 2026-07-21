#!/usr/bin/env python3
import subprocess
import threading
import time

from ulauncher.api.client.EventListener import EventListener
from ulauncher.api.client.Extension import Extension
from ulauncher.api.shared.action.OpenUrlAction import OpenUrlAction
from ulauncher.api.shared.action.RenderResultListAction import RenderResultListAction
from ulauncher.api.shared.event import KeywordQueryEvent, SystemExitEvent
from ulauncher.api.shared.item.ExtensionResultItem import ExtensionResultItem

from repositories import fetch_repositories, rank_repositories

OWNER = "paulrauchbach"
MAX_RESULTS = 12
REFRESH_SECONDS = 300


class QueryListener(EventListener):
    def on_event(self, event, extension):
        query = event.get_argument() or ""
        repositories, error = extension.snapshot()
        if error and not repositories:
            return RenderResultListAction([extension.message_item(error)])
        if not repositories:
            return RenderResultListAction(
                [extension.message_item("Loading GitHub repositories…")]
            )

        matches = rank_repositories(query, repositories)[:MAX_RESULTS]
        if not matches:
            return RenderResultListAction(
                [extension.message_item("No matching GitHub repository")]
            )
        return RenderResultListAction(
            [extension.repository_item(repository) for repository in matches]
        )


class ExitListener(EventListener):
    def on_event(self, _event, extension):
        extension.stop()


class GitHubRepositoriesExtension(Extension):
    def __init__(self):
        super().__init__()
        self._repositories = []
        self._error = None
        self._lock = threading.Lock()
        self._stopped = threading.Event()
        self.subscribe(KeywordQueryEvent, QueryListener())
        self.subscribe(SystemExitEvent, ExitListener())
        self._refresh_thread = threading.Thread(
            target=self._refresh_loop,
            name="github-repositories",
            daemon=True,
        )
        self._refresh_thread.start()

    def _refresh_loop(self):
        while not self._stopped.is_set():
            try:
                repositories = fetch_repositories(OWNER)
                with self._lock:
                    self._repositories = repositories
                    self._error = None
            except (subprocess.SubprocessError, OSError, ValueError) as error:
                with self._lock:
                    self._error = f"Could not load GitHub repositories: {error}"
            self._stopped.wait(REFRESH_SECONDS)

    def snapshot(self):
        with self._lock:
            return list(self._repositories), self._error

    def stop(self):
        self._stopped.set()

    @staticmethod
    def repository_item(repository):
        return ExtensionResultItem(
            icon="images/github.svg",
            name=repository["name"],
            description=repository["url"],
            on_enter=OpenUrlAction(repository["url"]),
        )

    @staticmethod
    def message_item(message):
        return ExtensionResultItem(
            icon="images/github.svg",
            name=message,
            description="Authenticate GitHub CLI with: gh auth login",
        )


if __name__ == "__main__":
    GitHubRepositoriesExtension().run()
